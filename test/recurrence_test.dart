import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/calendar/models/event.dart';
import 'package:taskmanager/features/calendar/models/recurrence.dart';

Event _event({
  required String start,
  String? end,
  String recurrence = '',
  String? until,
  bool isAllDay = true,
}) => Event(
  id: 1,
  title: 't',
  eventDate: start,
  startDate: start,
  endDate: end ?? start,
  createdAt: '',
  recurrence: recurrence,
  recurrenceUntil: until,
  isAllDay: isAllDay,
);

List<String> _starts(List<Event> events) =>
    events.map((e) => e.startDate!).toList();

void main() {
  group('expandOccurrences', () {
    test('반복 없음은 원본 그대로', () {
      final e = _event(start: '2026-10-05');
      expect(
        _starts(
          expandOccurrences(e, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        ),
        ['2026-10-05'],
      );
    });

    test('매주: 해당 월 회차만', () {
      final e = _event(start: '2026-09-02', recurrence: 'weekly');
      expect(
        _starts(
          expandOccurrences(e, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        ),
        ['2026-10-07', '2026-10-14', '2026-10-21', '2026-10-28'],
      );
    });

    test('매일: 종료일까지만', () {
      final e = _event(
        start: '2026-10-28',
        recurrence: 'daily',
        until: '2026-10-30',
      );
      expect(
        _starts(
          expandOccurrences(e, DateTime(2026, 10, 1), DateTime(2026, 11, 30)),
        ),
        ['2026-10-28', '2026-10-29', '2026-10-30'],
      );
    });

    test('매월 31일: 31일이 없는 달은 건너뜀', () {
      final e = _event(start: '2026-01-31', recurrence: 'monthly');
      expect(
        _starts(
          expandOccurrences(e, DateTime(2026, 1, 1), DateTime(2026, 6, 30)),
        ),
        ['2026-01-31', '2026-03-31', '2026-05-31'],
      );
    });

    test('매년 2월 29일: 윤년에만', () {
      final e = _event(start: '2024-02-29', recurrence: 'yearly');
      expect(
        _starts(
          expandOccurrences(e, DateTime(2024, 1, 1), DateTime(2028, 12, 31)),
        ),
        ['2024-02-29', '2028-02-29'],
      );
    });

    test('여러 날 일정은 이전 달에 시작해도 겹치면 포함, 기간 유지', () {
      final e = _event(
        start: '2026-09-29',
        end: '2026-10-02',
        recurrence: 'monthly',
      );
      final result = expandOccurrences(
        e,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31),
      );
      expect(_starts(result), ['2026-09-29', '2026-10-29']);
      expect(result.first.endDate, '2026-10-02');
      expect(result.last.endDate, '2026-11-01');
    });

    test('범위가 시작 전이면 없음', () {
      final e = _event(start: '2026-12-01', recurrence: 'daily');
      expect(
        expandOccurrences(e, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        isEmpty,
      );
    });

    test('오래된 매일 반복도 범위 근처부터 계산', () {
      final e = _event(start: '2016-01-01', recurrence: 'daily');
      expect(
        _starts(
          expandOccurrences(e, DateTime(2026, 10, 28), DateTime(2026, 10, 29)),
        ),
        ['2026-10-28', '2026-10-29'],
      );
    });
  });

  group('RRULE', () {
    test('생성', () {
      expect(toRRule(_event(start: '2026-10-01')), isNull);
      expect(
        toRRule(_event(start: '2026-10-01', recurrence: 'weekly')),
        'RRULE:FREQ=WEEKLY',
      );
      expect(
        toRRule(
          _event(start: '2026-10-01', recurrence: 'monthly', until: '2026-12-31'),
        ),
        'RRULE:FREQ=MONTHLY;UNTIL=20261231',
      );
      expect(
        toRRule(
          _event(
            start: '2026-10-01',
            recurrence: 'daily',
            until: '2026-12-31',
            isAllDay: false,
          ),
        ),
        'RRULE:FREQ=DAILY;UNTIL=20261231T235959Z',
      );
    });

  });
}
