import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../calendar/data/event_repository.dart';
import '../calendar/models/event.dart';
import '../calendar/models/recurrence.dart';
import '../mail/models/mail_message.dart';
import '../mail/services/mail_check_service.dart';
import '../todo/todo_provider.dart';

class BriefingData {
  final DateTime date;
  final List<Event> events;

  /// 메일 계정이 없거나 불러오지 못하면 null
  final ({List<MailMessage> messages, int total})? unreadMail;

  /// 할 일 탭의 남은 할 일 (기한 지난 것·오늘 것 먼저)
  final List<TodoItem> todos;
  final int totalTodoCount;

  const BriefingData({
    required this.date,
    required this.events,
    required this.unreadMail,
    required this.todos,
    required this.totalTodoCount,
  });
}

/// 브리핑에 표시할 할 일 최대 개수
const _maxTodos = 10;

final briefingProvider = FutureProvider.autoDispose<BriefingData>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 안 읽은 메일 (메일 연동 시): 다른 항목과 동시에 받고, 실패·지연되면 null
  // (메일 때문에 브리핑 전체가 멈추지 않도록)
  final unreadMailFuture = ref
      .read(mailCheckServiceProvider)
      .fetchUnread()
      .timeout(const Duration(seconds: 15))
      .then<({List<MailMessage> messages, int total})?>(
        (v) => v,
        onError: (Object e) {
          print('브리핑 메일 조회 실패: $e');
          return null;
        },
      );

  // 오늘 일정: 하루종일 → 시간순
  final events = await ref
      .read(eventRepositoryProvider)
      .getEventsInRange(today, today);
  events.sort((a, b) {
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
    return (a.startTime ?? '').compareTo(b.startTime ?? '');
  });

  // 할 일 탭의 남은 할 일, 기한 순 (메모 체크리스트는 넣지 않음)
  final all = (await ref.read(
    todoListProvider.future,
  )).where((t) => !t.done).toList()..sort(compareTodos);
  final todos = all.take(_maxTodos).toList();
  final totalTodoCount = all.length;
  final unreadMail = await unreadMailFuture;

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
