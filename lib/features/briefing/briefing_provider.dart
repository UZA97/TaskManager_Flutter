import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../calendar/data/event_repository.dart';
import '../calendar/models/event.dart';
import '../calendar/models/recurrence.dart';
import '../mail/models/mail_message.dart';
import '../mail/services/mail_check_service.dart';
import '../memo/data/note_repository.dart';
import '../memo/models/note.dart';
import 'briefing_todos.dart';

class BriefingTodo {
  final Note note;
  final String text;

  /// 메모 문서 안에서 체크리스트 노드의 위치
  final List<int> path;

  const BriefingTodo(this.note, this.text, this.path);
}

class BriefingData {
  final DateTime date;
  final List<Event> events;

  /// 메일 계정이 없거나 불러오지 못하면 null
  final ({List<MailMessage> messages, int total})? unreadMail;
  final List<BriefingTodo> todos;
  final int totalTodoCount;

  const BriefingData({
    required this.date,
    required this.events,
    required this.unreadMail,
    required this.todos,
    required this.totalTodoCount,
  });
}

/// 브리핑에 표시할 체크리스트 최대 개수
const _maxTodos = 10;

final briefingProvider = FutureProvider.autoDispose<BriefingData>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 오늘 일정: 하루종일 → 시간순
  final events = await ref
      .read(eventRepositoryProvider)
      .getEventsInRange(today, today);
  events.sort((a, b) {
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
    return (a.startTime ?? '').compareTo(b.startTime ?? '');
  });

  // 안 읽은 메일 (메일 연동 시)
  final unreadMail = await ref.read(mailCheckServiceProvider).fetchUnread();

  // 미완료 체크리스트: 최근 수정한 메모부터
  final notes = await ref.read(noteRepositoryProvider).getAllNotes();
  notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final todos = <BriefingTodo>[];
  var totalTodoCount = 0;
  for (final note in notes) {
    final items = uncheckedTodos(note.content);
    totalTodoCount += items.length;
    for (final item in items) {
      if (todos.length < _maxTodos) {
        todos.add(BriefingTodo(note, item.text, item.path));
      }
    }
  }

  return BriefingData(
    date: today,
    events: events,
    unreadMail: unreadMail,
    todos: todos,
    totalTodoCount: totalTodoCount,
  );
});

const _lastShownKey = 'briefing_last_shown';

/// 오늘 처음 실행이면 true를 반환하고, 오늘 표시한 것으로 기록.
Future<bool> claimDailyBriefing(AppDatabase db) async {
  final today = formatDate(DateTime.now());
  final row = await (db.select(
    db.settingTable,
  )..where((t) => t.key.equals(_lastShownKey))).getSingleOrNull();
  if (row?.value == today) return false;
  await db
      .into(db.settingTable)
      .insertOnConflictUpdate(
        SettingTableCompanion.insert(key: _lastShownKey, value: today),
      );
  return true;
}
