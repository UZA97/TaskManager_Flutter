import 'event.dart';

/// 반복 규칙. DB에는 [key] 문자열로 저장한다.
enum Recurrence {
  none('', '반복 안 함', null),
  daily('daily', '매일', 'DAILY'),
  weekly('weekly', '매주', 'WEEKLY'),
  monthly('monthly', '매월', 'MONTHLY'),
  yearly('yearly', '매년', 'YEARLY');

  const Recurrence(this.key, this.label, this.rruleFreq);

  final String key;
  final String label;
  final String? rruleFreq;

  static Recurrence fromKey(String? key) =>
      values.firstWhere((r) => r.key == key, orElse: () => none);
}

/// 반복 일정을 [from]~[to] (날짜 기준, 양끝 포함) 범위에 걸치는 회차들로 펼친다.
///
/// 각 회차는 원본과 같은 id를 가지며 날짜(eventDate/startDate/endDate)만 이동한다.
/// 여러 날에 걸친 일정은 시작일이 범위 이전이라도 범위에 겹치면 포함한다.
/// 매월 31일처럼 해당 날짜가 없는 달은 건너뛴다 (구글 캘린더 RRULE과 동일).
List<Event> expandOccurrences(Event master, DateTime from, DateTime to) {
  final rule = Recurrence.fromKey(master.recurrence);
  final start = _parseDate(master.startDate ?? master.eventDate);
  if (rule == Recurrence.none) return [master];

  final end = _parseDate(master.endDate ?? master.startDate ?? master.eventDate);
  final span = end.difference(start).inDays;
  final until = master.recurrenceUntil != null
      ? _parseDate(master.recurrenceUntil!)
      : null;

  final rangeFrom = _dateOnly(from);
  final rangeTo = _dateOnly(to);
  final result = <Event>[];

  // 범위 시작 직전 회차부터 계산해 불필요한 반복을 줄임
  var index = _firstIndexNear(
    rule,
    start,
    DateTime.utc(rangeFrom.year, rangeFrom.month, rangeFrom.day - span),
  );
  // 안전장치: 매일 반복 10년치 정도
  for (var guard = 0; guard < 4000; guard++, index++) {
    final occStart = _nthOccurrence(rule, start, index);
    if (occStart == null) continue; // 해당 날짜가 없는 달/해
    if (occStart.isAfter(rangeTo)) break;
    if (until != null && occStart.isAfter(until)) break;
    final occEnd = DateTime.utc(
      occStart.year,
      occStart.month,
      occStart.day + span,
    );
    if (occEnd.isBefore(rangeFrom)) continue;

    final startStr = formatDate(occStart);
    result.add(
      master.copyWith(
        eventDate: startStr,
        startDate: startStr,
        endDate: formatDate(occEnd),
      ),
    );
  }
  return result;
}

/// 구글 캘린더용 RRULE. 반복이 없으면 null.
String? toRRule(Event event) {
  final rule = Recurrence.fromKey(event.recurrence);
  final freq = rule.rruleFreq;
  if (freq == null) return null;
  final until = event.recurrenceUntil;
  if (until == null) return 'RRULE:FREQ=$freq';

  final d = until.replaceAll('-', '');
  // 시간 일정은 UNTIL을 UTC 일시로 지정해야 함 (종료일 하루 끝까지 포함)
  return event.isAllDay
      ? 'RRULE:FREQ=$freq;UNTIL=$d'
      : 'RRULE:FREQ=$freq;UNTIL=${d}T235959Z';
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String s) => _dateOnly(DateTime.parse(s));

// 날짜 계산은 서머타임 영향을 받지 않도록 UTC 자정 기준으로
DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

int _firstIndexNear(Recurrence rule, DateTime start, DateTime target) {
  if (!target.isAfter(start)) return 0;
  final days = target.difference(start).inDays;
  final index = switch (rule) {
    Recurrence.daily => days,
    Recurrence.weekly => days ~/ 7,
    Recurrence.monthly =>
      (target.year - start.year) * 12 + target.month - start.month,
    Recurrence.yearly => target.year - start.year,
    Recurrence.none => 0,
  };
  return index > 0 ? index - 1 : 0;
}

DateTime? _nthOccurrence(Recurrence rule, DateTime start, int n) {
  switch (rule) {
    case Recurrence.daily:
      return DateTime.utc(start.year, start.month, start.day + n);
    case Recurrence.weekly:
      return DateTime.utc(start.year, start.month, start.day + 7 * n);
    case Recurrence.monthly:
      final d = DateTime.utc(start.year, start.month + n, start.day);
      // DateTime이 넘친 날짜를 다음 달로 보정한 경우 → 그 달엔 해당 날짜 없음
      return d.day == start.day ? d : null;
    case Recurrence.yearly:
      final d = DateTime.utc(start.year + n, start.month, start.day);
      return d.day == start.day ? d : null;
    case Recurrence.none:
      return n == 0 ? start : null;
  }
}
