import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../models/recurrence.dart';

class GoogleCalendarService {
  static const _host = 'www.googleapis.com';
  static const _eventsPath = '/calendar/v3/calendars/primary/events';

  // 사용자 기본 캘린더의 시간대 (예: Asia/Seoul) — 반복 시간 일정에 필요
  static String? _calendarTimeZone;

  Future<String?> _getCalendarTimeZone(String accessToken) async {
    if (_calendarTimeZone != null) return _calendarTimeZone;
    final response = await http.get(
      Uri.https(_host, '/calendar/v3/calendars/primary'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      print('구글 캘린더 시간대 조회 실패: ${response.statusCode} ${response.body}');
      return null;
    }
    return _calendarTimeZone = jsonDecode(response.body)['timeZone'] as String?;
  }

  // 반복 시간 일정은 구글이 시간대를 요구함
  Future<Map<String, dynamic>> _buildBody(String accessToken, Event event) async {
    final needsTimeZone = event.isRecurring && !event.isAllDay;
    final timeZone = needsTimeZone
        ? await _getCalendarTimeZone(accessToken)
        : null;
    return _eventToGoogle(event, timeZone: timeZone);
  }

  // 이번 달 일정 가져오기. 요청 실패 시 null (빈 목록과 구분)
  Future<List<Event>?> getEvents(
    String accessToken,
    int year,
    int month,
  ) async {
    final timeMin = DateTime(year, month, 1).toUtc().toIso8601String();
    final timeMax = DateTime(year, month + 1, 1).toUtc().toIso8601String();

    final events = <Event>[];
    String? pageToken;
    do {
      final response = await http.get(
        Uri.https(_host, _eventsPath, {
          'timeMin': timeMin,
          'timeMax': timeMax,
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'maxResults': '250',
          if (pageToken != null) 'pageToken': pageToken,
        }),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        print('구글 캘린더 조회 실패: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        if (item['status'] == 'cancelled') continue;
        events.add(_googleEventToEvent(item as Map<String, dynamic>));
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    return events;
  }

  // 일정 추가 — 생성된 구글 이벤트 ID 반환
  Future<String?> addEvent(String accessToken, Event event) async {
    final response = await http.post(
      Uri.https(_host, _eventsPath),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(await _buildBody(accessToken, event)),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      print('구글 캘린더 추가 실패: ${response.statusCode} ${response.body}');
      return null;
    }
    final data = jsonDecode(response.body);
    return data['id'] as String?;
  }

  // 일정 수정
  Future<bool> updateEvent(String accessToken, Event event) async {
    if (event.googleEventId == null) return false;

    final response = await http.patch(
      Uri.https(_host, '$_eventsPath/${event.googleEventId}'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(await _buildBody(accessToken, event)),
    );

    if (response.statusCode != 200) {
      print('구글 캘린더 수정 실패: ${response.statusCode} ${response.body}');
      return false;
    }
    return true;
  }

  // 일정 삭제 — 이미 지워진 일정(404/410)도 성공으로 처리
  Future<bool> deleteEvent(String accessToken, String googleEventId) async {
    final response = await http.delete(
      Uri.https(_host, '$_eventsPath/$googleEventId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

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
        start = {'dateTime': _formatLocalDateTime(startAt), 'timeZone': timeZone};
        end = {'dateTime': _formatLocalDateTime(endAt), 'timeZone': timeZone};
      } else {
        start = {'dateTime': startAt.toUtc().toIso8601String()};
        end = {'dateTime': endAt.toUtc().toIso8601String()};
      }
    }

    final rrule = toRRule(event);
    return {
      'summary': event.title,
      'description': event.content,
      'location': event.locationName,
      'start': start,
      'end': end,
      // 수정 시 null을 보내면 반복이 해제됨
      'recurrence': rrule == null ? null : [rrule],
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
