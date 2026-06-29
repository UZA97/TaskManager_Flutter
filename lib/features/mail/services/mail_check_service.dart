import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/notification/notification_service.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import '../models/mail_message.dart';
import 'google_auth_service.dart';
import 'outlook_auth_service.dart';

class MailCheckService {
  Timer? _timer;
  final MailRepository _repo;
  final GoogleAuthService _authService = GoogleAuthService();
  String? _lastMessageId;
  String? _nextPageToken;
  String? get nextPageToken => _nextPageToken;

  MailCheckService(this._repo);

  Future<void> start(TaskMailAccount account) async {
    stop();

    // 앱 시작 시 현재 최신 메일 ID 초기화
    await _initLastMessageId(account);

    // 타이머 시작 (시작 시 바로 체크 제거 - _initLastMessageId로 대체)
    _timer = Timer.periodic(Duration(minutes: account.pollIntervalMinutes), (
      _,
    ) async {
      final latest = await _repo.getAccount();
      if (latest != null) await _checkNewMail(latest);
    });
  }

  Future<void> _initLastMessageId(TaskMailAccount account) async {
    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return;

      final response = await http.get(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages'
          '?q=is:unread&maxResults=1',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body);
      final messages = json['messages'] as List<dynamic>? ?? [];
      if (messages.isNotEmpty) {
        _lastMessageId = messages.first['id'] as String;
        print('초기 lastMessageId: $_lastMessageId');
      }
    } catch (e) {
      print('_initLastMessageId error: $e');
    }
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
    // refresh token으로 항상 새 token 발급
    if (account.refreshToken != null) {
      final newToken = await _authService.refreshAccessToken(
        account.refreshToken!,
      );
      if (newToken != null) {
        await _repo.saveAccount(account.copyWith(accessToken: newToken));
        return newToken;
      }
    }
    return account.accessToken;
  }

  Future<MailMessage?> _fetchMessageDetail(
    String accessToken,
    String messageId,
  ) async {
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

    final accessToken = await _getValidAccessToken(account);
    if (accessToken == null) return [];

    if (account.isOutlook) {
      return _fetchOutlookMessages(accessToken, count, pageToken);
    } else {
      return _fetchGmailMessages(accessToken, count, pageToken);
    }
  }

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

  Future<List<MailMessage>> _fetchOutlookMessages(
    String accessToken,
    int count,
    String? pageToken,
  ) async {
    try {
      String url =
          'https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages'
          '?\$top=$count&\$select=id,subject,from,receivedDateTime,isRead,bodyPreview'
          '&\$orderby=receivedDateTime desc';
      if (pageToken != null) url += '&\$skipToken=$pageToken';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        print('outlook fetchMessages error: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      final messages = data['value'] as List<dynamic>? ?? [];
      _nextPageToken = data['\@odata.nextLink'] as String?;

      return messages.map((msg) {
        final from = msg['from']?['emailAddress']?['address'] as String? ?? '';
        final subject = msg['subject'] as String? ?? '(제목 없음)';
        final preview = msg['bodyPreview'] as String? ?? '';
        final isRead = msg['isRead'] as bool? ?? false;
        DateTime date = DateTime.now();
        try {
          date = DateTime.parse(msg['receivedDateTime'] as String);
        } catch (_) {}

        return MailMessage(
          id: msg['id'] as String,
          subject: subject,
          from: from,
          preview: preview,
          date: date,
          isRead: isRead,
        );
      }).toList();
    } catch (e) {
      print('_fetchOutlookMessages error: $e');
      return [];
    }
  }

  Future<List<MailMessage>> _fetchGmailMessages(
    String accessToken,
    int count,
    String? pageToken,
  ) async {
    try {
      String url =
          'https://gmail.googleapis.com/gmail/v1/users/me/messages'
          '?maxResults=$count&labelIds=INBOX';
      if (pageToken != null) url += '&pageToken=$pageToken';

      final listResponse = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (listResponse.statusCode != 200) return [];

      final listJson = jsonDecode(listResponse.body);
      final messageIds = listJson['messages'] as List<dynamic>? ?? [];
      _nextPageToken = listJson['nextPageToken'] as String?;

      final messages = <MailMessage>[];
      for (final msg in messageIds) {
        final detail = await _fetchMessageDetail(
          accessToken,
          msg['id'] as String,
        );
        if (detail != null) messages.add(detail);
      }

      return messages;
    } catch (e) {
      print('_fetchGmailMessages error: $e');
      return [];
    }
  }
}

final mailCheckServiceProvider = Provider<MailCheckService>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return MailCheckService(repo);
});
