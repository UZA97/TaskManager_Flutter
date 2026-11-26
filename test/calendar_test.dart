import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/database/database.dart';
import 'package:taskmanager/core/database/database_provider.dart';
import 'package:taskmanager/features/calendar/data/event_repository.dart';
import 'package:taskmanager/features/calendar/models/event.dart';
import 'package:taskmanager/features/calendar/models/recurrence.dart';
import 'package:taskmanager/features/calendar/providers/event_provider.dart';
import 'package:taskmanager/features/calendar/views/calendar_editor_view.dart';

Event _event({
  required String start,
  String recurrence = '',
  int interval = 1,
  List<int> days = const [],
  List<String> exceptions = const [],
  String? until,
  bool isAllDay = true,
  String? startTime,
  String? endTime,
  String title = 't',
  String? location,
}) => Event(
  title: title,
  eventDate: start,
  startDate: start,
  endDate: start,
  createdAt: '',
  recurrence: recurrence,
  recurrenceInterval: interval,
  recurrenceDays: days,
  recurrenceExceptions: exceptions,
  recurrenceUntil: until,
  isAllDay: isAllDay,
  startTime: startTime,
  endTime: endTime,
  locationName: location,
);

List<String> _starts(Event e, DateTime from, DateTime to) =>
    expandOccurrences(e, from, to).map((o) => o.start).toList();

void main() {
  group('recurrence', () {
    final nov1 = DateTime(2026, 11, 1);
    final nov30 = DateTime(2026, 11, 30);

    test('격주', () {
      expect(
        _starts(
          _event(start: '2026-11-02', recurrence: 'weekly', interval: 2),
          nov1,
          nov30,
        ),
        ['2026-11-02', '2026-11-16', '2026-11-30'],
      );
    });

    test('매주 여러 요일, 격주 여러 요일', () {
      final monWed = _event(
        start: '2026-11-02',
        recurrence: 'weekly',
        days: [1, 3],
      );
      expect(_starts(monWed, nov1, DateTime(2026, 11, 15)), [
        '2026-11-02',
        '2026-11-04',
        '2026-11-09',
        '2026-11-11',
      ]);
      expect(
        _starts(monWed.copyWith(recurrenceInterval: 2), nov1, nov30),
        ['2026-11-02', '2026-11-04', '2026-11-16', '2026-11-18', '2026-11-30'],
      );
      // 먼 미래 범위도 같은 주기로
      expect(
        _starts(
          monWed.copyWith(recurrenceInterval: 2),
          DateTime(2027, 3, 1),
          DateTime(2027, 3, 14),
        ),
        ['2027-03-08', '2027-03-10'],
      );
    });

    test('3개월마다, 뺀 날짜는 제외', () {
      expect(
        _starts(
          _event(start: '2026-01-15', recurrence: 'monthly', interval: 3),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
        ),
        ['2026-01-15', '2026-04-15', '2026-07-15', '2026-10-15'],
      );
      expect(
        _starts(
          _event(
            start: '2026-11-02',
            recurrence: 'daily',
            exceptions: ['2026-11-03'],
            until: '2026-11-04',
          ),
          nov1,
          nov30,
        ),
        ['2026-11-02', '2026-11-04'],
      );
    });

    test('RRULE·EXDATE·설명', () {
      final e = _event(
        start: '2026-11-02',
        recurrence: 'weekly',
        interval: 2,
        days: [3, 1],
        until: '2026-12-31',
        exceptions: ['2026-11-16'],
      );
      expect(
        toRRule(e),
        'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20261231',
      );
      expect(toExDate(e), 'EXDATE;VALUE=DATE:20261116');
      expect(
        toExDate(
          e.copyWith(isAllDay: false, startTime: '09:30'),
          timeZone: 'Asia/Seoul',
        ),
        'EXDATE;TZID=Asia/Seoul:20261116T093000',
      );
      expect(toExDate(_event(start: '2026-11-02')), isNull);
      expect(recurrenceSummary(e), '2주마다 월, 수 · 2026년 12월 31일까지');
      expect(
        recurrenceSummary(_event(start: '2026-11-02', recurrence: 'monthly')),
        '매월',
      );
    });

    test('달력 범위와 주 시작', () {
      final r = monthGridRange(DateTime(2026, 11));
      expect((r.from, r.to), (DateTime(2026, 11, 1), DateTime(2026, 12, 5)));
      expect(weekStartOf(DateTime(2026, 11, 26)), DateTime(2026, 11, 22));
    });
  });

  test('repository: 회차 빼기, 검색, 삭제 키', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = EventRepository(db);
    final id = await repo.addEvent(
      _event(
        start: '2026-11-02',
        recurrence: 'weekly',
        interval: 2,
        days: [1, 3],
        title: '팀 회의',
        location: '3층 회의실',
      ),
    );
    await repo.addRecurrenceException(id, '2026-11-04');
    final saved = (await repo.getEventById(id))!;
    expect(saved.recurrenceInterval, 2);
    expect(saved.recurrenceDays, [1, 3]);
    expect(saved.recurrenceExceptions, ['2026-11-04']);
    final starts = (await repo.getEventsInRange(
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 20),
    )).map((e) => e.start);
    expect(starts, ['2026-11-02', '2026-11-16', '2026-11-18']);

    expect((await repo.searchEvents('회의')).single.id, id);
    expect((await repo.searchEvents('3층')).single.id, id);
    expect(await repo.searchEvents('없는말'), isEmpty);
    expect(await repo.searchEvents('%'), isEmpty);

    final key = EventRepository.pendingDeleteKey('a#holiday@group', 'ev1');
    expect(EventRepository.parsePendingDeleteKey(key), ('a#holiday@group', 'ev1'));
    expect(EventRepository.parsePendingDeleteKey('ev2'), ('', 'ev2'));
  });

  group('calendar screen', () {
    late AppDatabase db;
    late EventRepository repo;
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1300, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = EventRepository(db);
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      container.read(currentMonthProvider.notifier).showDate(DateTime(2026, 11));
      container.read(selectedDateProvider.notifier).select(DateTime(2026, 11, 10));
    }

    Future<void> show(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CalendarEditorView())),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> cleanUp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    }

    Future<void> dragTo(WidgetTester tester, Finder from, Offset to) async {
      final gesture = await tester.startGesture(
        tester.getCenter(from),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('월 보기: 일정을 끌어 다른 날로 옮김', (tester) async {
      await pump(tester);
      final id = await repo.addEvent(_event(start: '2026-11-10', title: '병원'));
      await show(tester);

      await dragTo(
        tester,
        find.text('병원'),
        tester.getCenter(find.byKey(const ValueKey('calendar-cell-2026-11-12'))),
      );
      expect((await repo.getEventById(id))!.start, '2026-11-12');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-cell-2026-11-12')),
          matching: find.text('병원'),
        ),
        findsOneWidget,
      );
      await cleanUp(tester);
    });

    testWidgets('반복 일정: 이 일정만 삭제', (tester) async {
      await pump(tester);
      final id = await repo.addEvent(
        _event(start: '2026-11-03', recurrence: 'weekly', title: '운동'),
      );
      await show(tester);
      expect(find.text('운동'), findsNWidgets(5)); // 11월 3·10·17·24, 12월 1

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-cell-2026-11-17')),
          matching: find.text('운동'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scope-this')));
      await tester.pumpAndSettle();

      expect((await repo.getEventById(id))!.recurrenceExceptions, ['2026-11-17']);
      expect(find.text('운동'), findsNWidgets(4));
      await cleanUp(tester);
    });

    testWidgets('반복 일정: 이 일정만 수정하면 따로 떼어 냄', (tester) async {
      await pump(tester);
      final id = await repo.addEvent(
        _event(start: '2026-11-03', recurrence: 'weekly', title: '운동'),
      );
      await show(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-cell-2026-11-10')),
          matching: find.text('운동'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '운동'), '수영');
      await tester.tap(find.byKey(const ValueKey('event-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scope-this')));
      await tester.pumpAndSettle();

      expect((await repo.getEventById(id))!.recurrenceExceptions, ['2026-11-10']);
      final onDay = await repo.getEventsInRange(
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 10),
      );
      expect(onDay.map((e) => (e.title, e.isRecurring)), [('수영', false)]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-cell-2026-11-17')),
          matching: find.text('운동'),
        ),
        findsOneWidget,
      );
      await cleanUp(tester);
    });

    testWidgets('주 보기: 시간 일정을 끌어 2시간 뒤로', (tester) async {
      await pump(tester);
      final id = await repo.addEvent(
        _event(
          start: '2026-11-10',
          title: '미팅',
          isAllDay: false,
          startTime: '10:00',
          endTime: '11:00',
        ),
      );
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('calendar-mode-week')));
      await tester.pumpAndSettle();
      expect(find.text('2026년 11월 8일 – 14일'), findsOneWidget);

      final chip = find.textContaining('미팅', findRichText: true);
      expect(chip, findsOneWidget);
      await dragTo(
        tester,
        chip,
        tester.getCenter(chip) + const Offset(0, 48 * 2.0), // 1시간 = 48px
      );
      final moved = (await repo.getEventById(id))!;
      expect((moved.start, moved.startTime, moved.endTime), (
        '2026-11-10',
        '12:00',
        '13:00',
      ));
      await cleanUp(tester);
    });

    testWidgets('검색 결과를 누르면 그 일정이 열림', (tester) async {
      await pump(tester);
      await repo.addEvent(_event(start: '2027-02-14', title: '결혼기념일'));
      await show(tester);

      await tester.enterText(
        find.byKey(const ValueKey('calendar-search')),
        '기념',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-search-result-0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-search-result-0')));
      await tester.pumpAndSettle();
      expect(find.text('일정 편집'), findsOneWidget);
      expect(container.read(currentMonthProvider).month, 2);
      expect(container.read(selectedDateProvider), DateTime(2027, 2, 14));
      await cleanUp(tester);
    });
  });
}
