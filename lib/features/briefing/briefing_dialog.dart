import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/navigation_provider.dart';
import '../calendar/models/event.dart';
import '../calendar/providers/event_provider.dart';
import '../mail/models/mail_message.dart';
import '../mail/providers/mail_provider.dart';
import '../memo/providers/note_provider.dart';
import 'briefing_ai_dialog.dart';
import 'briefing_provider.dart';

const _accent = Color(0xFF4A90E2);
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

// 메인 탭 순서 (main.dart의 _navigationDestinations)
const _memoTab = 0;
const _calendarTab = 1;
const _mailTab = 2;

Future<void> showBriefingDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const BriefingDialog());

/// 오늘 일정 · 안 읽은 메일 · 미완료 체크리스트를 한 화면에 보여주는 브리핑
class BriefingDialog extends ConsumerWidget {
  const BriefingDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefing = ref.watch(briefingProvider);
    final now = DateTime.now();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, color: _accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘 브리핑',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${now.month}월 ${now.day}일 '
                          '${_weekdays[now.weekday - 1]}요일',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '이번 주 날씨 · 주요 뉴스 (AI)',
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    onPressed: () => showAiBriefingDialog(context),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: briefing.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('브리핑을 불러오지 못했습니다: $e'),
                ),
                data: (data) => ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _Section(
                      icon: Icons.event,
                      title: '오늘 일정',
                      count: data.events.length,
                      empty: '오늘 일정이 없어요',
                      children: [
                        for (final e in data.events)
                          _EventTile(event: e, date: data.date),
                      ],
                    ),
                    _Section(
                      icon: Icons.mail_outline,
                      title: '안 읽은 메일',
                      count: data.unreadMail?.total,
                      empty: data.unreadMail == null
                          ? '메일 계정이 연동되지 않았어요'
                          : '안 읽은 메일이 없어요',
                      children: [
                        for (final m in data.unreadMail?.messages ?? const [])
                          _MailTile(mail: m),
                      ],
                    ),
                    _Section(
                      icon: Icons.check_box_outlined,
                      title: '미완료 체크리스트',
                      count: data.totalTodoCount,
                      empty: '남은 체크리스트가 없어요',
                      children: [
                        for (final t in data.todos) _TodoTile(todo: t),
                        if (data.totalTodoCount > data.todos.length)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(52, 4, 24, 4),
                            child: Text(
                              '외 ${data.totalTodoCount - data.todos.length}개',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final String empty;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.count,
    required this.empty,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(fontSize: 11, color: _accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 4, 24, 4),
              child: Text(
                empty,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _EventTile extends ConsumerWidget {
  final Event event;
  final DateTime date;

  const _EventTile({required this.event, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = event.isAllDay
        ? '하루종일'
        : [event.startTime, event.endTime].whereType<String>().join(' ~ ');

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: SizedBox(
        width: 72,
        child: Text(
          time,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      title: Text(
        event.title,
        style: TextStyle(
          decoration: event.isCompleted ? TextDecoration.lineThrough : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: event.locationName != null
          ? Text(event.locationName!, overflow: TextOverflow.ellipsis)
          : null,
      trailing: event.isRecurring
          ? const Icon(Icons.repeat, size: 14, color: Colors.grey)
          : null,
      onTap: () {
        ref.read(currentMonthProvider.notifier)
          ..setYear(date.year)
          ..setMonth(date.month);
        ref.read(selectedDateProvider.notifier).select(date);
        ref.read(navigationProvider.notifier).navigateTo(_calendarTab);
        Navigator.pop(context);
      },
    );
  }
}

class _MailTile extends ConsumerWidget {
  final MailMessage mail;

  const _MailTile({required this.mail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: const SizedBox(
        width: 72,
        child: Icon(Icons.circle, size: 8, color: _accent),
      ),
      title: Text(mail.subject, overflow: TextOverflow.ellipsis),
      subtitle: Text(mail.from, overflow: TextOverflow.ellipsis),
      onTap: () {
        ref.read(selectedMailProvider.notifier).select(mail);
        ref.read(navigationProvider.notifier).navigateTo(_mailTab);
        Navigator.pop(context);
      },
    );
  }
}

class _TodoTile extends ConsumerWidget {
  final BriefingTodo todo;

  const _TodoTile({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: const SizedBox(
        width: 72,
        child: Icon(Icons.check_box_outline_blank, size: 16),
      ),
      title: Text(todo.text, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        todo.note.title.isEmpty ? '(제목 없음)' : todo.note.title,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        // 메모를 연 뒤 해당 체크리스트로 커서 이동
        ref
            .read(memoFocusRequestProvider.notifier)
            .request((
              noteId: todo.note.id!,
              path: todo.path,
              text: todo.text,
            ));
        ref.read(selectedNoteProvider.notifier).select(todo.note);
        ref.read(navigationProvider.notifier).navigateTo(_memoTab);
        Navigator.pop(context);
      },
    );
  }
}
