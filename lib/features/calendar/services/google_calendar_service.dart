import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';

class GoogleCalendarService {
  static const _baseUrl = 'https://www.googleapis.com/calendar/v3';

  // 이번 달 일정 가져오기
  Future<List<Event>> getEvents(String accessToken, int year, int month) async {
    final timeMin = DateTime(year, month, 1).toUtc().toIso8601String();
    final timeMax = DateTime(
      year,
      month + 1,
      0,
      23,
      59,
      59,
    ).toUtc().toIso8601String();

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/calendars/primary/events'
        '?timeMin=$timeMin'
        '&timeMax=$timeMax'
        '&singleEvents=true'
        '&orderBy=startTime',
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body);
    final items = data['items'] as List<dynamic>? ?? [];

    return items.map((item) {
      final start =
          item['start']['date'] as String? ??
          (item['start']['dateTime'] as String).substring(0, 10);

      return Event(
        id: null,
        title: item['summary'] as String? ?? '(제목 없음)',
        eventDate: start,
        createdAt: DateTime.now().toIso8601String(),
        googleEventId: item['id'] as String?,
      );
    }).toList();
  }

  // 일정 추가
  Future<String?> addEvent(String accessToken, Event event) async {
    final start = event.isAllDay
        ? {'date': event.startDate ?? event.eventDate}
        : {
            'dateTime':
                '${event.startDate ?? event.eventDate}T${event.startTime ?? '00:00'}:00',
          };

    final end = event.isAllDay
        ? {'date': event.endDate ?? event.eventDate}
        : {
            'dateTime':
                '${event.endDate ?? event.eventDate}T${event.endTime ?? '00:00'}:00',
          };

    final response = await http.post(
      Uri.parse('$_baseUrl/calendars/primary/events'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'summary': event.title,
        'description': event.content,
        'location': event.locationName,
        'start': {'date': start},
        'end': {'date': end},
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) return null;
    final data = jsonDecode(response.body);
    return data['id'] as String?;
  }

  // 다운로드할 때 Google 포맷 → 우리 포맷
  Event _googleEventToEvent(Map<String, dynamic> item) {
    final isAllDay = item['start']['date'] != null;
    final startDate = isAllDay
        ? item['start']['date'] as String
        : (item['start']['dateTime'] as String).substring(0, 10);
    final endDate = isAllDay
        ? item['end']['date'] as String
        : (item['end']['dateTime'] as String).substring(0, 10);
    final startTime = isAllDay
        ? null
        : (item['start']['dateTime'] as String).substring(11, 16);
    final endTime = isAllDay
        ? null
        : (item['end']['dateTime'] as String).substring(11, 16);

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
    );
  }

  // 일정 삭제
  Future<bool> deleteEvent(String accessToken, String googleEventId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/calendars/primary/events/$googleEventId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    return response.statusCode == 204;
  }

  // 일정 수정
  Future<bool> updateEvent(String accessToken, Event event) async {
    if (event.googleEventId == null) return false;

    final response = await http.patch(
      Uri.parse('$_baseUrl/calendars/primary/events/${event.googleEventId}'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'summary': event.title,
        'start': {'date': event.eventDate},
        'end': {'date': event.eventDate},
      }),
    );

    return response.statusCode == 200;
  }
}
