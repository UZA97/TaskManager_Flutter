import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/notification/notification_service.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import '../models/mail_message.dart';
import '../../../core/auth/google_account_provider.dart';

class MailCheckService {
  Timer? _timer;
  final MailRepository _repo;
  final Future<String?> Function() _getGoogleAccessToken;
  String? _lastMessageId;
  String? _nextPageToken;
  String? get nextPageToken => _nextPageToken;

  MailCheckService(this._repo, this._getGoogleAccessToken);

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
      }
    } catch (e) {
      // 초기 메일 ID 조회 중 오류 발생 시 무시
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
      // 새 메일 확인 중 오류 발생 시 무시
    }
  }

  Future<String?> _getValidAccessToken(TaskMailAccount account) =>
      _getGoogleAccessToken();

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

  Future<void> markAsRead(String messageId) async {
    final account = await _repo.getAccount();
    if (account == null) return;
    final accessToken = await _getValidAccessToken(account);
    if (accessToken == null) return;

    final response = await http.post(
      Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId/modify',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'removeLabelIds': ['UNREAD'],
      }),
    );
    if (response.statusCode != 200) {
      print('읽음 처리 실패: ${response.statusCode} - ${response.body}');
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

    return _fetchGmailMessages(accessToken, count, pageToken);
  }

  /// 메일을 Gmail 휴지통으로 이동 (30일 후 Gmail이 영구 삭제, 그 전엔 복구 가능).
  /// 성공한 메일 ID 반환. 메일 계정이 없으면 빈 집합.
  Future<Set<String>> trashMessages(List<String> ids) async {
    final account = await _repo.getAccount();
    if (account == null) return {};
    final accessToken = await _getValidAccessToken(account);
    if (accessToken == null) return {};

    final trashed = <String>{};
    for (final id in ids) {
      try {
        final response = await http.post(
          Uri.https(
            'gmail.googleapis.com',
            '/gmail/v1/users/me/messages/$id/trash',
          ),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (response.statusCode == 200) {
          trashed.add(id);
        } else {
          print('메일 삭제 실패($id): ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        print('메일 삭제 오류($id): $e');
      }
    }
    return trashed;
  }

  /// 받은편지함의 안 읽은 메일을 모두 읽음 처리 (Gmail에도 반영).
  /// 처리한 개수를 반환. 메일 계정이 없거나 실패하면 null.
  Future<int?> markAllAsRead() async {
    final account = await _repo.getAccount();
    if (account == null) return null;
    final accessToken = await _getValidAccessToken(account);
    if (accessToken == null) return null;
    final headers = {'Authorization': 'Bearer $accessToken'};

    try {
      // 1. 안 읽은 메일 ID 수집 (페이지당 최대 500)
      final ids = <String>[];
      String? pageToken;
      do {
        final response = await http.get(
          Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages', {
            'q': 'is:unread in:inbox',
            'maxResults': '500',
            if (pageToken != null) 'pageToken': pageToken,
          }),
          headers: headers,
        );
        if (response.statusCode != 200) {
          print('안 읽은 메일 조회 실패: ${response.statusCode} ${response.body}');
          return null;
        }
        final json = jsonDecode(response.body);
        for (final msg in json['messages'] as List<dynamic>? ?? []) {
          ids.add(msg['id'] as String);
        }
        pageToken = json['nextPageToken'] as String?;
      } while (pageToken != null);

      // 2. batchModify는 요청당 최대 1000개
      for (var i = 0; i < ids.length; i += 1000) {
        final chunk = ids.sublist(i, (i + 1000).clamp(0, ids.length));
        final response = await http.post(
          Uri.https(
            'gmail.googleapis.com',
            '/gmail/v1/users/me/messages/batchModify',
          ),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'ids': chunk,
            'removeLabelIds': ['UNREAD'],
          }),
        );
        // 성공 시 204 (빈 응답)
        if (response.statusCode != 204 && response.statusCode != 200) {
          print('모두 읽음 처리 실패: ${response.statusCode} ${response.body}');
          return null;
        }
      }
      return ids.length;
    } catch (e) {
      print('모두 읽음 처리 오류: $e');
      return null;
    }
  }

  /// 받은편지함의 안 읽은 메일 (최신 [count]개)과 전체 안 읽은 개수(추정치).
  /// 메일 계정이 없거나 실패하면 null.
  Future<({List<MailMessage> messages, int total})?> fetchUnread({
    int count = 5,
  }) async {
    final account = await _repo.getAccount();
    if (account == null) return null;
    final accessToken = await _getValidAccessToken(account);
    if (accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages', {
          'q': 'is:unread in:inbox',
          'maxResults': '$count',
        }),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final ids = json['messages'] as List<dynamic>? ?? [];
      final messages = <MailMessage>[];
      for (final msg in ids) {
        final detail = await _fetchMessageDetail(
          accessToken,
          msg['id'] as String,
        );
        if (detail != null) messages.add(detail);
      }
      final total = json['resultSizeEstimate'] as int? ?? messages.length;
      return (messages: messages, total: total);
    } catch (e) {
      return null;
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
      return [];
    }
  }

  Future<String?> getGoogleAccessToken() async {
    final account = await _repo.getAccount();
    if (account == null) return null;
    return _getValidAccessToken(account);
  }
}

final mailCheckServiceProvider = Provider<MailCheckService>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return MailCheckService(
    repo,
    () => ref.read(googleAccountProvider.notifier).getAccessToken(),
  );
});
