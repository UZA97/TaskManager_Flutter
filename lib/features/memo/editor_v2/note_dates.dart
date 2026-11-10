/// 메모 글 속의 날짜 (누르면 캘린더 일정으로 만들 수 있음)
class DateMention {
  const DateMention(this.start, this.end, this.date, {this.hasTime = false});

  /// 글자 범위 [start, end)
  final int start;
  final int end;

  /// 시간이 없으면 0시 0분
  final DateTime date;
  final bool hasTime;

  @override
  bool operator ==(Object other) =>
      other is DateMention &&
      other.start == start &&
      other.end == end &&
      other.date == date &&
      other.hasTime == hasTime;

  @override
  int get hashCode => Object.hash(start, end, date, hasTime);
}

// 2026-11-09 / 2026.11.09 / 2026/11/9 / 2026년 11월 9일 / 11월 9일 (+ 요일)
final _datePattern = RegExp(
  r'(?<![\d.])(?:(\d{4})\s*([-./])\s*(\d{1,2})\s*\2\s*(\d{1,2})|'
  r'(?:(\d{4})년\s*)?(\d{1,2})월\s*(\d{1,2})일)'
  r'(?![\d])(?:\s*\([월화수목금토일]\))?',
);

// 날짜 바로 뒤의 시간: 15:30 / 오후 3:30 / 오후 3시 / 3시 30분
final _timePattern = RegExp(
  r'\s+(?:(오전|오후)\s*)?(\d{1,2})(?::(\d{2})|시(?:\s*(\d{1,2})분)?)(?!\d)',
);

/// [text] 안의 날짜들. 없는 날짜(2월 30일 등)는 제외.
List<DateMention> findDateMentions(String text, {DateTime? now}) {
  if (!text.contains(RegExp(r'\d'))) return const [];
  final year = (now ?? DateTime.now()).year;
  final result = <DateMention>[];
  for (final m in _datePattern.allMatches(text)) {
    final isNumeric = m.group(1) != null;
    final y = int.parse(isNumeric ? m.group(1)! : (m.group(5) ?? '$year'));
    final mo = int.parse(isNumeric ? m.group(3)! : m.group(6)!);
    final d = int.parse(isNumeric ? m.group(4)! : m.group(7)!);
    if (mo < 1 || mo > 12 || d < 1 || d > DateTime(y, mo + 1, 0).day) {
      continue;
    }
    var end = m.end;
    var date = DateTime(y, mo, d);
    var hasTime = false;
    final t = _timePattern.matchAsPrefix(text, m.end);
    if (t != null) {
      var h = int.parse(t.group(2)!);
      final min = int.parse(t.group(3) ?? t.group(4) ?? '0');
      final ampm = t.group(1);
      if (ampm == '오후' && h < 12) h += 12;
      if (ampm == '오전' && h == 12) h = 0;
      if (h <= 23 && min <= 59) {
        date = DateTime(y, mo, d, h, min);
        hasTime = true;
        end = t.end;
      }
    }
    result.add(DateMention(m.start, end, date, hasTime: hasTime));
  }
  return result;
}
