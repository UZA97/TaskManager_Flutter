import 'dart:async';
import 'package:flutter/services.dart';
import 'features/memo/providers/note_provider.dart';
import 'features/memo/providers/tab_provider.dart';
import '../features/calendar/data/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/notification/notification_service.dart';
import 'core/tray/tray_service.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/app_settings.dart';
import 'features/lock/views/lock_screen.dart';
import 'features/memo/views/memo_list_view.dart';
import 'features/memo/views/memo_editor_view.dart';
import 'features/calendar/views/calendar_view.dart';
import 'features/calendar/views/calendar_editor_view.dart';
import 'features/settings/views/settings_view.dart';
import 'features/mail/views/mail_list_view.dart';
import 'features/mail/views/mail_detail_view.dart';
import 'features/map/views/map_view.dart';
import 'features/map/views/map_sidebar_view.dart';
import 'core/providers/navigation_provider.dart';
import 'features/settings/views/settings_detail_view.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'features/mail/data/mail_repository.dart';
import 'features/mail/services/mail_check_service.dart';
import 'core/database/database_provider.dart';
import 'core/update/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 윈도우 앱의 표시/종료 동작을 제어하기 위해 window_manager 초기화
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(650, 400),
      center: true,
      title: 'TaskManager',
      skipTaskbar: false,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  await NotificationService.setup();

  runApp(const ProviderScope(child: TaskManagerApp()));
}

class TaskManagerApp extends ConsumerWidget {
  const TaskManagerApp({super.key});

  /// 앱 설정에 따라 사용할 기본 글자 크기를 계산합니다.
  double _fontSizeBase(AppFontSize size) => switch (size) {
    AppFontSize.small => 12.0,
    AppFontSize.medium => 14.0,
    AppFontSize.large => 16.0,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final fontSize = settings?.fontSize ?? AppFontSize.medium;
    final base = _fontSizeBase(fontSize);

    return MaterialApp(
      title: 'TaskManager',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings?.themeColor ?? const Color(0xFF4A90E2),
        ).copyWith(primary: settings?.themeColor ?? const Color(0xFF4A90E2)),
        useMaterial3: true,
        textTheme: TextTheme(
          bodySmall: TextStyle(fontSize: base - 2),
          bodyMedium: TextStyle(fontSize: base),
          bodyLarge: TextStyle(fontSize: base + 2),
          titleSmall: TextStyle(fontSize: base + 2),
          titleMedium: TextStyle(fontSize: base + 4),
          titleLarge: TextStyle(fontSize: base + 6),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings?.themeColor ?? const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ).copyWith(primary: settings?.themeColor ?? const Color(0xFF4A90E2)),
        useMaterial3: true,
        textTheme: TextTheme(
          bodySmall: TextStyle(fontSize: base - 2),
          bodyMedium: TextStyle(fontSize: base),
          bodyLarge: TextStyle(fontSize: base + 2),
          titleSmall: TextStyle(fontSize: base + 2),
          titleMedium: TextStyle(fontSize: base + 4),
          titleLarge: TextStyle(fontSize: base + 6),
        ),
      ),
      themeMode: settings?.themeMode ?? ThemeMode.light,
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  /// 메인 앱의 좌측 네비게이션과 우측 콘텐츠 영역을 구성하는 상태 위젯입니다.
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WindowListener {
  /// 앱 실행 중 트레이 동작과 창 표시/종료를 담당하는 서비스입니다.
  final _trayService = TrayService();
  bool _isLocked = false;
  final Set<int> _notifiedEventIds = {};

  /// 메인 화면 좌측 네비게이션에 표시할 항목 목록입니다.
  static const List<NavigationRailDestination> _navigationDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.note, color: Colors.white),
      selectedIcon: Icon(Icons.note, color: Color(0xFF4A90E2)),
      label: Text('메모'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.calendar_month, color: Colors.white),
      selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF4A90E2)),
      label: Text('캘린더'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.mail, color: Colors.white),
      selectedIcon: Icon(Icons.mail, color: Color(0xFF4A90E2)),
      label: Text('메일'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.map, color: Colors.white),
      selectedIcon: Icon(Icons.map, color: Color(0xFF4A90E2)),
      label: Text('지도'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings, color: Colors.white),
      selectedIcon: Icon(Icons.settings, color: Color(0xFF4A90E2)),
      label: Text('설정'),
    ),
  ];

  /// 메인 화면 좌측 패널에 보여줄 사이드바 콘텐츠 목록입니다.
  static const List<Widget> _sidePanels = [
    MemoListView(),
    CalendarView(),
    MailListView(),
    MapSidebarView(),
    SettingsView(),
  ];

  /// 메인 화면 우측 콘텐츠 영역에 보여줄 상세 뷰 목록입니다.
  static const List<Widget> _detailPanels = [
    MemoEditorView(),
    CalendarEditorView(),
    MailDetailView(),
    MapView(),
    SettingsDetailView(),
  ];

  @override
  void onWindowClose() async {
    final settings = ref.read(settingsProvider).value;
    if (settings?.trayModeEnabled ?? true) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  // 트레이에서 복귀할 때 잠금 체크
  Future<void> _showWindow() async {
    final settings = ref.read(settingsProvider).value;
    if (settings?.lockEnabled ?? false) {
      setState(() => _isLocked = true);
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Timer? _alarmTimer;
  Timer? _focusModeTimer;
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 메일 폴링 시작
      final mailAccount = await ref.read(mailRepositoryProvider).getAccount();
      if (mailAccount != null) {
        ref.read(mailCheckServiceProvider).start(mailAccount);
      }

      // 알람 체커 시작
      _startAlarmChecker();

      // 앱 시작 시 잠금 체크
      final settings = ref.read(settingsProvider).value;
      if (settings?.lockEnabled ?? false) {
        setState(() => _isLocked = true);
      }
      _checkForUpdate();
    });

    _startFocusModeChecker();
  }

  void _startFocusModeChecker() {
    _focusModeTimer?.cancel();
    _focusModeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkFocusModeEnd();
    });
  }

  void _checkFocusModeEnd() {
    final settings = ref.read(settingsProvider).value;
    if (settings == null) return;
    if (!settings.focusModeEnabled) return;

    // 집중모드 종료 시간인지 체크
    final now = TimeOfDay.now();
    final end = _parseTime(settings.focusModeEnd);
    if (now.hour == end.hour && now.minute == end.minute) {
      // 집중모드 종료 시간 도달 - 알림으로 알려줌
      NotificationService.show(
        title: '집중모드 종료',
        body: '집중모드가 종료되었습니다. 알림이 다시 활성화됩니다.',
      );
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateService().checkForUpdate();
    if (!result.hasUpdate) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(result: result),
    );
  }

  void _startAlarmChecker() {
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAlarms();
    });
  }

  Future<void> _checkAlarms() async {
    final settings = ref.read(settingsProvider).value;
    if (!(settings?.notificationEnabled ?? true)) {
      return;
    }

    final db = ref.read(databaseProvider);
    final repo = EventRepository(db);
    final events = await repo.getAllAlarmEvents();
    print('알람 이벤트 수: ${events.length}');

    final now = DateTime.now();
    for (final event in events) {
      if (!event.alarmEnabled) continue;

      final eventDate = DateTime.parse(event.eventDate);
      final alarmMinutesBefore = event.alarmDaysBefore;

      DateTime eventDateTime;
      if (event.startTime != null) {
        final parts = event.startTime!.split(':');
        eventDateTime = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      } else {
        eventDateTime = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          9,
          0,
        );
      }

      final alarmDateTime = eventDateTime.subtract(
        Duration(minutes: alarmMinutesBefore),
      );
      final diff = alarmDateTime.difference(now).inMinutes;
      // 알람 시각이 지났거나 1분 이내인 경우
      if (diff <= 0 && diff >= -1) {
        if (_notifiedEventIds.contains(event.id)) continue; // 중복 방지
        _notifiedEventIds.add(event.id!);
        await NotificationService.show(title: '📅 일정 알람', body: event.title);
      }
    }
  }

  Future<void> _initTray() async {
    await _trayService.init(
      onShow: _showWindow, // 트레이 클릭 시 창을 보이고 잠금 상태를 체크합니다.
      onExit: () async {
        await windowManager.destroy();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 잠금 화면
    if (_isLocked) {
      return LockScreen(onUnlocked: () => setState(() => _isLocked = false));
    }

    return Scaffold(
      body: Row(
        children: [
          // 왼쪽 네비게이션 패널
          NavigationRail(
            backgroundColor: const Color(0xFF2C2C2C),
            selectedIndex: ref.watch(navigationProvider),
            onDestinationSelected: (index) {
              ref.read(navigationProvider.notifier).navigateTo(index);
            },
            labelType: NavigationRailLabelType.none,
            destinations: _navigationDestinations,
          ),
          Container(
            width: 250,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: // 사이드 패널
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(ref.watch(navigationProvider)),
                child: _sidePanels[ref.watch(navigationProvider)],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFFDDDDDD)),
          // 메인 패널
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(ref.watch(navigationProvider)),
                child: _detailPanels[ref.watch(navigationProvider)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _alarmTimer?.cancel();
    windowManager.removeListener(this);
    _focusModeTimer?.cancel();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (!ctrl) return false;

    final tabState = ref.read(tabProvider).value;
    if (tabState == null || tabState.tabNoteIds.isEmpty) return false;

    // 현재 탭이 메모 탭일 때만
    if (ref.read(navigationProvider) != 0) return false;

    final ids = tabState.tabNoteIds;
    final currentIndex = ids.indexOf(tabState.activeNoteId ?? -1);
    final notes = ref.read(noteListProvider).value ?? [];

    if (event.logicalKey == LogicalKeyboardKey.tab && !shift) {
      // Ctrl+Tab: 다음 탭
      final nextId = ids[(currentIndex + 1) % ids.length];
      ref.read(tabProvider.notifier).setActive(nextId);
      final note = notes.firstWhere(
        (n) => n.id == nextId,
        orElse: () => notes.first,
      );
      ref.read(selectedNoteProvider.notifier).select(note);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab && shift) {
      // Ctrl+Shift+Tab: 이전 탭
      final prevId = ids[(currentIndex - 1 + ids.length) % ids.length];
      ref.read(tabProvider.notifier).setActive(prevId);
      final note = notes.firstWhere(
        (n) => n.id == prevId,
        orElse: () => notes.first,
      );
      ref.read(selectedNoteProvider.notifier).select(note);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyW && !shift) {
      // Ctrl+W: 현재 탭 닫기
      if (tabState.activeNoteId == null) return false;
      ref.read(tabProvider.notifier).closeTab(tabState.activeNoteId!);
      final newState = ref.read(tabProvider).value;
      if (newState?.activeNoteId != null) {
        final note = notes.firstWhere(
          (n) => n.id == newState!.activeNoteId,
          orElse: () => notes.first,
        );
        ref.read(selectedNoteProvider.notifier).select(note);
      } else {
        ref.read(selectedNoteProvider.notifier).select(null);
      }
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyW && shift) {
      // Ctrl+Shift+W: 전체 탭 닫기
      final allIds = List<int>.from(ids);
      for (final id in allIds) {
        ref.read(tabProvider.notifier).closeTab(id);
      }
      ref.read(selectedNoteProvider.notifier).select(null);
      return true;
    }

    return false;
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateCheckResult result;
  const _UpdateDialog({required this.result});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('업데이트 가능'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('현재 버전: ${widget.result.currentVersion}'),
          Text('최신 버전: ${widget.result.latestVersion}'),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '다운로드 중... ${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: _isDownloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에'),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _isDownloading = true);
                  await UpdateService().downloadAndInstall(
                    widget.result.downloadUrl!,
                    onProgress: (progress) {
                      setState(() => _progress = progress);
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('업데이트'),
              ),
            ],
    );
  }
}
