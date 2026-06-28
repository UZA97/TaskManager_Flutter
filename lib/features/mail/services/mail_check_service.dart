import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/notification/notification_service.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import '../models/mail_message.dart';
import 'google_auth_service.dart';

class MailCheckService {
  Timer? _timer;
  final MailRepository _repo;
  final GoogleAuthService _authService = GoogleAuthService();
  String? _lastMessageId; // 마지막으로 확인한 메일 ID

  MailCheckService(this._repo);

  Future<void> start(TaskMailAccount account) async {
    stop();
    await _checkNewMail(account); // 시작하자마자 한 번
    _timer = Timer.periodic(
      Duration(minutes: account.pollIntervalMinutes),
      (_) async {
        final latest = await _repo.getAccount();
        if (latest != null) await _checkNewMail(latest);
      },
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNewMail(TaskMailAccount account) async {
    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return;

      // 안읽은 메일 목록 조회
      final response = await http.get(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages'
          '?q=is:unread&maxResults=10',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body);
      final messages = json['messages'] as List<dynamic>? ?? [];

      if (messages.isEmpty) return;

      final latestId = messages.first['id'] as String;
      if (latestId == _lastMessageId) return; // 새 메일 없음

      // 새 메일들만 알림
      for (final msg in messages) {
        final id = msg['id'] as String;
        if (id == _lastMessageId) break;

        final detail = await _fetchMessageDetail(accessToken, id);
        if (detail != null) {
          await NotificationService.show(
            title: '📧 새 메일 - ${detail.from}',
            body: detail.subject,
          );
        }
      }

      _lastMessageId = latestId;
    } catch (e) {
      print('_checkNewMail error: $e');
    }
  }

  Future<String?> _getValidAccessToken(TaskMailAccount account) async {
    if (account.accessToken != null) return account.accessToken;
    if (account.refreshToken == null) return null;

    final newToken =
        await _authService.refreshAccessToken(account.refreshToken!);
    if (newToken != null) {
      final updated = account.copyWith(accessToken: newToken);
      await _repo.saveAccount(updated);
    }
    return newToken;
  }

  Future<MailMessage?> _fetchMessageDetail(
      String accessToken, String messageId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId'
          '?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final headers = json['payload']['headers'] as List<dynamic>;

      String subject = '(제목 없음)';
      String from = '';
      DateTime date = DateTime.now();

      for (final header in headers) {
        final name = header['name'] as String;
        final value = header['value'] as String;
        if (name == 'Subject') subject = value;
        if (name == 'From') from = value;
        if (name == 'Date') {
          try {
            date = DateTime.parse(value);
          } catch (_) {}
        }
      }

      final snippet = json['snippet'] as String? ?? '';
      final isUnread = (json['labelIds'] as List<dynamic>).contains('UNREAD');

      return MailMessage(
        id: messageId,
        subject: subject,
        from: from,
        preview: snippet,
        date: date,
        isRead: !isUnread,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<MailMessage>> fetchMessages({
    int count = 20,
    String? pageToken,
  }) async {
    final account = await _repo.getAccount();
    if (account == null) return [];

    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return [];

      String url = 'https://gmail.googleapis.com/gmail/v1/users/me/messages'
          '?maxResults=$count&labelIds=INBOX';
      if (pageToken != null) url += '&pageToken=$pageToken';

      final listResponse = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (listResponse.statusCode != 200) return [];

      final listJson = jsonDecode(listResponse.body);
      final messageIds = listJson['messages'] as List<dynamic>? ?? [];
      _nextPageToken = listJson['nextPageToken'] as String?; // 저장

      final messages = <MailMessage>[];
      for (final msg in messageIds) {
        final detail =
            await _fetchMessageDetail(accessToken, msg['id'] as String);
        if (detail != null) messages.add(detail);
      }

      return messages;
    } catch (e) {
      print('fetchMessages error: $e');
      return [];
    }
  }

  String? _nextPageToken;
  String? get nextPageToken => _nextPageToken;

  Future<bool> testConnection(TaskMailAccount account) async {
    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return false;

      final response = await http.get(
        Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/profile'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

final mailCheckServiceProvider = Provider<MailCheckService>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return MailCheckService(repo);
});
