import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../models/recurrence.dart';

// 일정 수정 결과 — notFound면 구글에서 지워진 일정
enum GoogleUpdateResult { ok, failed, notFound }

/// 구글 계정의 캘린더 하나 (기본·공유·구독·공휴일 등)
class GoogleCalendarInfo {
  const GoogleCalendarInfo({
    required this.id,
    required this.name,
    required this.color,
    required this.primary,
    required this.writable,
    required this.selected,
  });

  /// 기본 캘린더는 '' (DB의 calendarId와 같게)
  final String id;
  final String name;

  /// '#RRGGBB'
  final String color;
  final bool primary;

  /// 일정을 고칠 수 있는지 (공휴일·구독 캘린더는 읽기 전용)
  final bool writable;

  /// 구글 캘린더 화면에서 보이게 해 둔 캘린더인지
  final bool selected;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'primary': primary,
    'writable': writable,
    'selected': selected,
  };

  factory GoogleCalendarInfo.fromJson(Map<String, dynamic> json) =>
      GoogleCalendarInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '#4A90E2',
        primary: json['primary'] as bool? ?? false,
        writable: json['writable'] as bool? ?? true,
        selected: json['selected'] as bool? ?? true,
      );
}

class GoogleCalendarService {
  static const _host = 'www.googleapis.com';
  // 오프라인 등에서 무한 대기 방지
  static const _timeout = Duration(seconds: 15);

  /// 캘린더의 일정 주소 ('' = 기본 캘린더). ID의 @ 등은 경로에 맞게 인코딩됨
  static Uri _eventsUri(
    String calendarId, [
    String? eventId,
    Map<String, String>? query,
  ]) => Uri(
    scheme: 'https',
    host: _host,
    pathSegments: [
      'calendar',
      'v3',
      'calendars',
      calendarId.isEmpty ? 'primary' : calendarId,
      'events',
      ?eventId,
    ],
    queryParameters: query,
  );

  /// 계정의 캘린더 목록 (숨긴 캘린더 제외). 실패하면 null.
  Future<List<GoogleCalendarInfo>?> getCalendars(String accessToken) async {
    final calendars = <GoogleCalendarInfo>[];
    String? pageToken;
    do {
      final response = await http
          .get(
            Uri.https(_host, '/calendar/v3/users/me/calendarList', {
              'minAccessRole': 'reader',
              'pageToken': ?pageToken,
            }),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        print('구글 캘린더 목록 조회 실패: ${response.statusCode} ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      for (final item in data['items'] as List<dynamic>? ?? const []) {
        if (item['hidden'] == true || item['deleted'] == true) continue;
        final primary = item['primary'] == true;
        final role = item['accessRole'] as String? ?? 'reader';
        calendars.add(
          GoogleCalendarInfo(
            id: primary ? '' : item['id'] as String,
            name:
                item['summaryOverride'] as String? ??
                item['summary'] as String? ??
                '',
            color: item['backgroundColor'] as String? ?? '#4A90E2',
            primary: primary,
            writable: role == 'owner' || role == 'writer',
            selected: primary || item['selected'] == true,
          ),
        );
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
    // 기본 캘린더를 맨 앞에
    calendars.sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0));
    return calendars;
  }

  // 사용자 기본 캘린더의 시간대 (예: Asia/Seoul) — 반복 시간 일정에 필요
  static String? _calendarTimeZone;

  Future<String?> _getCalendarTimeZone(String accessToken) async {
    if (_calendarTimeZone != null) return _calendarTimeZone;
    final response = await http
        .get(
          Uri.https(_host, '/calendar/v3/calendars/primary'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      print('구글 캘린더 시간대 조회 실패: ${response.statusCode} ${response.body}');
      return null;
    }
    return _calendarTimeZone = jsonDecode(response.body)['timeZone'] as String?;
  }

  // 반복 시간 일정은 구글이 시간대를 요구함
  Future<Map<String, dynamic>> _buildBody(
    String accessToken,
    Event event,
  ) async {
    final needsTimeZone = event.isRecurring && !event.isAllDay;
    final timeZone = needsTimeZone
        ? await _getCalendarTimeZone(accessToken)
        : null;
    return _eventToGoogle(event, timeZone: timeZone);
  }

  /// [from]~[to] (날짜, 양끝 포함) 일정 가져오기. 요청 실패 시 null (빈 목록과 구분)
  Future<List<Event>?> getEvents(
    String accessToken,
    DateTime from,
    DateTime to, {
    String calendarId = '',
  }) async {
    final timeMin = DateTime(
      from.year,
      from.month,
      from.day,
    ).toUtc().toIso8601String();
    final timeMax = DateTime(
      to.year,
      to.month,
      to.day + 1,
    ).toUtc().toIso8601String();

    final events = <Event>[];
    String? pageToken;
    do {
      final response = await http
          .get(
            _eventsUri(calendarId, null, {
              'timeMin': timeMin,
              'timeMax': timeMax,
              'singleEvents': 'true',
              'orderBy': 'startTime',
              'maxResults': '250',
              'pageToken': ?pageToken,
            }),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        print('구글 캘린더 조회 실패: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        if (item['status'] == 'cancelled') continue;
        events.add(
          _googleEventToEvent(
            item as Map<String, dynamic>,
          ).copyWith(calendarId: calendarId),
        );
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    return events;
  }

  // 일정 추가 — 생성된 구글 이벤트 ID 반환
  Future<String?> addEvent(String accessToken, Event event) async {
    final response = await http
        .post(
          _eventsUri(event.calendarId),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(await _buildBody(accessToken, event)),
        )
        .timeout(_timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      print('구글 캘린더 추가 실패: ${response.statusCode} ${response.body}');
      return null;
    }
    final data = jsonDecode(response.body);
    return data['id'] as String?;
  }

  // 일정 수정
  Future<GoogleUpdateResult> updateEvent(
    String accessToken,
    Event event,
  ) async {
    if (event.googleEventId == null) return GoogleUpdateResult.failed;

    final response = await http
        .patch(
          _eventsUri(event.calendarId, event.googleEventId),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(await _buildBody(accessToken, event)),
        )
        .timeout(_timeout);

    if (response.statusCode == 404 || response.statusCode == 410) {
      return GoogleUpdateResult.notFound;
    }
    if (response.statusCode != 200) {
      print('구글 캘린더 수정 실패: ${response.statusCode} ${response.body}');
      return GoogleUpdateResult.failed;
    }
    return GoogleUpdateResult.ok;
  }

  // 일정 삭제 — 이미 지워진 일정(404/410)도 성공으로 처리
  Future<bool> deleteEvent(
    String accessToken,
    String googleEventId, {
    String calendarId = '',
  }) async {
    final response = await http
        .delete(
          _eventsUri(calendarId, googleEventId),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(_timeout);

    final ok =
        response.statusCode == 204 ||
        response.statusCode == 404 ||
        response.statusCode == 410;
    if (!ok) {
      print('구글 캘린더 삭제 실패: ${response.statusCode} ${response.body}');
    }
    return ok;
  }

  // 우리 포맷 → Google 포맷
  Map<String, dynamic> _eventToGoogle(Event event, {String? timeZone}) {
    final startDate = event.startDate ?? event.eventDate;
    final endDate = event.endDate ?? startDate;

    Map<String, String> start;
    Map<String, String> end;
    if (event.isAllDay) {
      // 구글의 종일 일정 end.date는 "다음 날"(exclusive)
      start = {'date': startDate};
      end = {
        'date': _formatDate(
          DateTime.parse(endDate).add(const Duration(days: 1)),
        ),
      };
    } else {
      final startAt = _parseLocal(startDate, event.startTime ?? '09:00');
      var endAt = event.endTime != null
          ? _parseLocal(endDate, event.endTime!)
          : startAt.add(const Duration(hours: 1));
      if (!endAt.isAfter(startAt))
        endAt = startAt.add(const Duration(hours: 1));
      if (timeZone != null) {
        // 반복 일정: 현지 시각 + 시간대 (회차마다 같은 현지 시각 유지)
        start = {
          'dateTime': _formatLocalDateTime(startAt),
          'timeZone': timeZone,
        };
        end = {'dateTime': _formatLocalDateTime(endAt), 'timeZone': timeZone};
      } else {
        start = {'dateTime': startAt.toUtc().toIso8601String()};
        end = {'dateTime': endAt.toUtc().toIso8601String()};
      }
    }

    final rrule = toRRule(event);
    final exdate = toExDate(event, timeZone: timeZone);
    return {
      'summary': event.title,
      'description': event.content,
      'location': event.locationName,
      'start': start,
      'end': end,
      // 수정 시 null을 보내면 반복이 해제됨
      'recurrence': rrule == null ? null : [rrule, ?exdate],
    };
  }

  // Google 포맷 → 우리 포맷
  Event _googleEventToEvent(Map<String, dynamic> item) {
    final isAllDay = item['start']['date'] != null;

    String startDate;
    String endDate;
    String? startTime;
    String? endTime;
    if (isAllDay) {
      startDate = item['start']['date'] as String;
      // exclusive end → 우리 포맷의 마지막 날로 변환
      final exclusiveEnd = DateTime.parse(
        item['end']?['date'] as String? ?? startDate,
      );
      final lastDay = exclusiveEnd.subtract(const Duration(days: 1));
      endDate = lastDay.isBefore(DateTime.parse(startDate))
          ? startDate
          : _formatDate(lastDay);
    } else {
      final startAt = DateTime.parse(
        item['start']['dateTime'] as String,
      ).toLocal();
      final endAt = DateTime.parse(
        item['end']?['dateTime'] as String? ??
            item['start']['dateTime'] as String,
      ).toLocal();
      startDate = _formatDate(startAt);
      endDate = _formatDate(endAt);
      startTime = _formatTime(startAt);
      endTime = _formatTime(endAt);
    }

    return Event(
      title: item['summary'] as String? ?? '(제목 없음)',
      eventDate: startDate,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      content: item['description'] as String?,
      locationName: item['location'] as String?,
      createdAt: DateTime.now().toIso8601String(),
      googleEventId: item['id'] as String?,
      googleRecurringEventId: item['recurringEventId'] as String?,
    );
  }

  static DateTime _parseLocal(String date, String time) {
    final d = DateTime.parse(date);
    final parts = time.split(':');
    return DateTime(
      d.year,
      d.month,
      d.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _formatLocalDateTime(DateTime d) =>
      '${_formatDate(d)}T${_formatTime(d)}:00';

  static String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
