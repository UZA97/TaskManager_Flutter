import 'event.dart';

/// 반복 규칙. DB에는 [key] 문자열로 저장한다.
enum Recurrence {
  none('', '반복 안 함', null, ''),
  daily('daily', '매일', 'DAILY', '일'),
  weekly('weekly', '매주', 'WEEKLY', '주'),
  monthly('monthly', '매월', 'MONTHLY', '개월'),
  yearly('yearly', '매년', 'YEARLY', '년');

  const Recurrence(this.key, this.label, this.rruleFreq, this.unit);

  final String key;
  final String label;
  final String? rruleFreq;

  /// "2주마다"처럼 간격을 붙일 때의 단위
  final String unit;

  static Recurrence fromKey(String? key) =>
      values.firstWhere((r) => r.key == key, orElse: () => none);
}

const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
const _rruleDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// 매주 반복의 요일 (DateTime.weekday, 정렬). 지정이 없으면 시작일의 요일
List<int> weeklyDays(Event event) {
  final days = {
    for (final d in event.recurrenceDays)
      if (d >= 1 && d <= 7) d,
  };
  if (days.isEmpty) days.add(_parseDate(event.start).weekday);
  return days.toList()..sort();
}

/// 반복 설명 (예: "2주마다 월, 수", "매월", "3일마다 · 12월 31일까지")
String recurrenceSummary(Event event) {
  final rule = Recurrence.fromKey(event.recurrence);
  if (rule == Recurrence.none) return rule.label;
  final interval = event.recurrenceInterval < 1 ? 1 : event.recurrenceInterval;
  var text = interval == 1 ? rule.label : '$interval${rule.unit}마다';
  if (rule == Recurrence.weekly && event.recurrenceDays.isNotEmpty) {
    text += ' ${weeklyDays(event).map((d) => weekdayLabels[d - 1]).join(', ')}';
  }
  final until = event.recurrenceUntil;
  if (until != null) {
    final d = _parseDate(until);
    text += ' · ${d.year}년 ${d.month}월 ${d.day}일까지';
  }
  return text;
}

/// 반복 일정을 [from]~[to] (날짜 기준, 양끝 포함) 범위에 걸치는 회차들로 펼친다.
///
/// 각 회차는 원본과 같은 id를 가지며 날짜(eventDate/startDate/endDate)만 이동한다.
/// 여러 날에 걸친 일정은 시작일이 범위 이전이라도 범위에 겹치면 포함한다.
/// 매월 31일처럼 해당 날짜가 없는 달은 건너뛴다 (구글 캘린더 RRULE과 동일).
/// [Event.recurrenceExceptions]에 든 날짜의 회차는 뺀다.
List<Event> expandOccurrences(Event master, DateTime from, DateTime to) {
  final rule = Recurrence.fromKey(master.recurrence);
  if (rule == Recurrence.none) return [master];
  final start = _parseDate(master.start);
  final span = _parseDate(master.end).difference(start).inDays;
  final until = master.recurrenceUntil != null
      ? _parseDate(master.recurrenceUntil!)
      : null;
  final interval = master.recurrenceInterval < 1
      ? 1
      : master.recurrenceInterval;
  final exceptions = master.recurrenceExceptions.toSet();

  final rangeFrom = _dateOnly(from);
  final rangeTo = _dateOnly(to);
  // 범위 시작 직전에 시작해 범위까지 이어지는 회차도 포함
  final target = DateTime.utc(
    rangeFrom.year,
    rangeFrom.month,
    rangeFrom.day - span,
  );
  final result = <Event>[];

  void add(DateTime occStart) {
    final startStr = formatDate(occStart);
    if (exceptions.contains(startStr)) return;
    final occEnd = DateTime.utc(
      occStart.year,
      occStart.month,
      occStart.day + span,
    );
    if (occEnd.isBefore(rangeFrom)) return;
    result.add(
      master.copyWith(
        eventDate: startStr,
        startDate: startStr,
        endDate: formatDate(occEnd),
      ),
    );
  }

  bool past(DateTime d) =>
      d.isAfter(rangeTo) || (until != null && d.isAfter(until));

  if (rule == Recurrence.weekly) {
    // 시작일이 든 주(월요일 기준)부터 [interval]주마다, 그 주의 고른 요일들
    final days = weeklyDays(master);
    final firstWeek = DateTime.utc(
      start.year,
      start.month,
      start.day - (start.weekday - 1),
    );
    var week = 0;
    if (target.isAfter(firstWeek)) {
      week = target.difference(firstWeek).inDays ~/ (7 * interval) - 1;
      if (week < 0) week = 0;
    }
    for (var guard = 0; guard < 4000; guard++, week++) {
      final monday = DateTime.utc(
        firstWeek.year,
        firstWeek.month,
        firstWeek.day + 7 * interval * week,
      );
      if (past(monday)) break;
      for (final weekday in days) {
        final d = DateTime.utc(
          monday.year,
          monday.month,
          monday.day + weekday - 1,
        );
        if (d.isBefore(start) || past(d)) continue;
        add(d);
      }
    }
    return result;
  }

  // 범위 시작 직전 회차부터 계산해 불필요한 반복을 줄임 (안전장치: 매일 반복 10년치 정도)
  var index = _firstIndexNear(rule, start, target, interval);
  for (var guard = 0; guard < 4000; guard++, index++) {
    final occStart = _nthOccurrence(rule, start, index * interval);
    if (occStart == null) continue; // 해당 날짜가 없는 달/해
    if (past(occStart)) break;
    add(occStart);
  }
  return result;
}

/// 구글 캘린더용 RRULE. 반복이 없으면 null.
String? toRRule(Event event) {
  final rule = Recurrence.fromKey(event.recurrence);
  final freq = rule.rruleFreq;
  if (freq == null) return null;
  final parts = ['FREQ=$freq'];
  if (event.recurrenceInterval > 1) {
    parts.add('INTERVAL=${event.recurrenceInterval}');
  }
  if (rule == Recurrence.weekly && event.recurrenceDays.isNotEmpty) {
    parts.add(
      'BYDAY=${weeklyDays(event).map((d) => _rruleDays[d - 1]).join(',')}',
    );
  }
  final until = event.recurrenceUntil;
  if (until != null) {
    final d = until.replaceAll('-', '');
    // 시간 일정은 UNTIL을 UTC 일시로 지정해야 함 (종료일 하루 끝까지 포함)
    parts.add(event.isAllDay ? 'UNTIL=$d' : 'UNTIL=${d}T235959Z');
  }
  return 'RRULE:${parts.join(';')}';
}

/// 구글 캘린더용 EXDATE (뺀 회차). 없으면 null.
/// 시간 일정은 회차의 시작 시각으로 지정해야 함 ([timeZone]이 있으면 현지 시각).
String? toExDate(Event event, {String? timeZone}) {
  if (!event.isRecurring || event.recurrenceExceptions.isEmpty) return null;
  final dates = [...event.recurrenceExceptions]..sort();
  if (event.isAllDay) {
    return 'EXDATE;VALUE=DATE:${dates.map((d) => d.replaceAll('-', '')).join(',')}';
  }
  final time = (event.startTime ?? '09:00').replaceAll(':', '');
  if (timeZone != null) {
    return 'EXDATE;TZID=$timeZone:'
        '${dates.map((d) => '${d.replaceAll('-', '')}T${time}00').join(',')}';
  }
  final utc = [
    for (final d in dates)
      _compactUtc(
        DateTime.parse('${d}T${event.startTime ?? '09:00'}:00').toUtc(),
      ),
  ];
  return 'EXDATE:${utc.join(',')}';
}

String _compactUtc(DateTime d) =>
    '${formatDate(d).replaceAll('-', '')}T'
    '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}00Z';

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String s) => _dateOnly(DateTime.parse(s));

// 날짜 계산은 서머타임 영향을 받지 않도록 UTC 자정 기준으로
DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// [target] 직전 회차의 번호 (간격 단위)
int _firstIndexNear(
  Recurrence rule,
  DateTime start,
  DateTime target,
  int interval,
) {
  if (!target.isAfter(start)) return 0;
  final days = target.difference(start).inDays;
  final periods = switch (rule) {
    Recurrence.daily => days,
    Recurrence.weekly => days ~/ 7,
    Recurrence.monthly =>
      (target.year - start.year) * 12 + target.month - start.month,
    Recurrence.yearly => target.year - start.year,
    Recurrence.none => 0,
  };
  final index = periods ~/ interval;
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
