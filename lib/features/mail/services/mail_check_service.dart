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
  static const _timeout = Duration(seconds: 15);
  static const _maxSeenIds = 500;

  Timer? _timer;
  final MailRepository _repo;
  final Future<String?> Function() _getGoogleAccessToken;
  // start/stop마다 증가 — 이전 세대의 진행 중 확인이 알림을 띄우지 않도록
  int _generation = 0;
  bool _checking = false;
  // 이미 본 안읽은 메일 ID (삽입 순서 유지, 오래된 것부터 제거)
  final _seenIds = <String>{};
  // 이 계정으로 처음 확인한 시각 — 그 이전에 받은 메일은 알리지 않음
  String? _seededEmail;
  DateTime? _watermark;
  String? _nextPageToken;
  String? get nextPageToken => _nextPageToken;

  MailCheckService(this._repo, this._getGoogleAccessToken);

  // 여러 번 불려도 타이머는 하나만 (await 전에 타이머를 먼저 설정)
  Future<void> start(TaskMailAccount account) async {
    stop();
    final generation = _generation;

    _timer = Timer.periodic(Duration(minutes: account.pollIntervalMinutes), (
      _,
    ) async {
      final latest = await _repo.getAccount();
      if (latest != null) await _checkNewMail(latest, generation);
    });

    // 시작 시 현재 안읽은 메일을 "이미 본 것"으로 기록 (알림 없음)
    await _checkNewMail(account, generation);
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNewMail(TaskMailAccount account, int generation) async {
    if (_checking) return; // 이전 확인이 아직 진행 중
    _checking = true;
    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null || generation != _generation) return;

      // 안읽은 메일 목록 조회
      final response = await http
          .get(
            Uri.parse(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages'
              '?q=is:unread&maxResults=10',
            ),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body);
      final ids = [
        for (final m in json['messages'] as List<dynamic>? ?? [])
          m['id'] as String,
      ];

      // 첫 확인: 기준만 잡고 알림 없음
      if (_seededEmail != account.email) {
        _seenIds
          ..clear()
          ..addAll(ids);
        _seededEmail = account.email;
        _watermark = DateTime.now().subtract(const Duration(minutes: 5));
        return;
      }

      final newIds = ids.where((id) => !_seenIds.contains(id)).toList();
      if (newIds.isEmpty) return;
      _seenIds.addAll(newIds);
      while (_seenIds.length > _maxSeenIds) {
        _seenIds.remove(_seenIds.first);
      }

      for (final id in newIds) {
        final raw = await _fetchMessageRaw(accessToken, id);
        if (raw == null || generation != _generation) continue;
        // 오래된 안읽은 메일이 목록에 새로 보이는 경우(최신 메일을 읽음) 제외
        final received = int.tryParse(raw['internalDate'] as String? ?? '');
        final watermark = _watermark;
        if (received != null &&
            watermark != null &&
            DateTime.fromMillisecondsSinceEpoch(received).isBefore(watermark)) {
          continue;
        }
        final detail = _parseMessage(id, raw);
        if (detail == null) continue;
        await NotificationService.show(
          title: '📧 새 메일 - ${detail.from}',
          body: detail.subject,
        );
      }
    } catch (e) {
      // 새 메일 확인 중 오류 발생 시 무시
    } finally {
      _checking = false;
    }
  }

  Future<String?> _getValidAccessToken(TaskMailAccount account) =>
      _getGoogleAccessToken();

  Future<MailMessage?> _fetchMessageDetail(
    String accessToken,
    String messageId,
  ) async {
    final raw = await _fetchMessageRaw(accessToken, messageId);
    return raw == null ? null : _parseMessage(messageId, raw);
  }

  // 상세 조회를 5개씩 동시에 (순서 유지)
  Future<List<MailMessage>> _fetchMessageDetails(
    String accessToken,
    List<String> ids,
  ) async {
    const concurrency = 5;
    final messages = <MailMessage>[];
    for (var i = 0; i < ids.length; i += concurrency) {
      final chunk = ids.sublist(i, (i + concurrency).clamp(0, ids.length));
      final details = await Future.wait(
        chunk.map((id) => _fetchMessageDetail(accessToken, id)),
      );
      messages.addAll(details.whereType<MailMessage>());
    }
    return messages;
  }

  Future<Map<String, dynamic>?> _fetchMessageRaw(
    String accessToken,
    String messageId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId'
              '?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date',
            ),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  MailMessage? _parseMessage(String messageId, Map<String, dynamic> json) {
    try {
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

    final response = await http
        .post(
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
        )
        .timeout(_timeout);
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
        final response = await http
            .post(
              Uri.https(
                'gmail.googleapis.com',
                '/gmail/v1/users/me/messages/$id/trash',
              ),
              headers: {'Authorization': 'Bearer $accessToken'},
            )
            .timeout(_timeout);
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
        final response = await http
            .get(
              Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages', {
                'q': 'is:unread in:inbox',
                'maxResults': '500',
                if (pageToken != null) 'pageToken': pageToken,
              }),
              headers: headers,
            )
            .timeout(_timeout);
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
        final response = await http
            .post(
              Uri.https(
                'gmail.googleapis.com',
                '/gmail/v1/users/me/messages/batchModify',
              ),
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode({
                'ids': chunk,
                'removeLabelIds': ['UNREAD'],
              }),
            )
            .timeout(_timeout);
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
      final response = await http
          .get(
            Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages', {
              'q': 'is:unread in:inbox',
              'maxResults': '$count',
            }),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final ids = json['messages'] as List<dynamic>? ?? [];
      final messages = await _fetchMessageDetails(accessToken, [
        for (final msg in ids) msg['id'] as String,
      ]);
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

      final response = await http
          .get(
            Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/profile'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);

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

      final listResponse = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);

      if (listResponse.statusCode != 200) return [];

      final listJson = jsonDecode(listResponse.body);
      final messageIds = listJson['messages'] as List<dynamic>? ?? [];
      _nextPageToken = listJson['nextPageToken'] as String?;

      return _fetchMessageDetails(accessToken, [
        for (final msg in messageIds) msg['id'] as String,
      ]);
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
  final service = MailCheckService(
    repo,
    () => ref.read(googleAccountProvider.notifier).getAccessToken(),
  );
  // provider가 다시 만들어질 때 이전 타이머가 남지 않도록
  ref.onDispose(service.stop);
  return service;
});
