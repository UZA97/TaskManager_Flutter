import 'dart:async';
import 'dart:io';
import 'core/config/app_config.dart';
import 'package:flutter/services.dart';
import 'core/auth/google_account_provider.dart';
import 'features/mail/widgets/google_login_dialog.dart';
import 'features/memo/data/note_repository.dart';
import 'features/memo/providers/note_provider.dart';
import 'features/memo/providers/tab_provider.dart';
import '../features/calendar/data/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'core/hotkey/quick_memo_hotkey.dart';
import 'core/notification/notification_service.dart';
import 'core/tray/tray_service.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_colors.dart';
import 'features/lock/views/lock_screen.dart';
import 'features/memo/views/memo_list_view.dart';
import 'features/memo/widgets/quick_memo_dialog.dart';
import 'features/memo/editor_v2/memo_editor_v2_view.dart';
import 'features/calendar/views/calendar_view.dart';
import 'features/calendar/views/calendar_editor_view.dart';
import 'features/settings/views/settings_view.dart';
import 'features/mail/views/mail_list_view.dart';
import 'features/mail/views/mail_detail_view.dart';
import 'features/map/views/map_view.dart';
import 'features/map/views/map_sidebar_view.dart';
import 'core/providers/navigation_provider.dart';
import 'features/settings/views/settings_detail_view.dart';
import 'features/mail/providers/mail_provider.dart';
import 'features/calendar/models/event.dart';
import 'features/calendar/models/recurrence.dart';
import 'features/calendar/providers/event_provider.dart';
import 'features/mail/services/mail_check_service.dart';
import 'core/database/database_provider.dart';
import 'core/update/update_service.dart';
import 'features/briefing/briefing_dialog.dart';
import 'features/briefing/briefing_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 옛 폴더의 예전 exe로 켜졌으면 설치된 새 버전으로 바꿔 실행
  // (바로가기가 옛 폴더를 가리켜 업데이트해도 예전 버전이 뜨는 문제)
  if (await UpdateService().relaunchInstalledIfNewer()) exit(0);
  // 구글 OAuth·Gemini 키 (config/*.json 에셋)
  await AppConfig.load();

  // 윈도우 앱의 표시/종료 동작을 제어하기 위해 window_manager 초기화
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  // 빠른 메모 단축키: 이전 실행에서 남은 등록 정리
  await hotKeyManager.unregisterAll();
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

  // NotificationService가 설정(알림 on/off, 집중모드)을 읽을 수 있도록 컨테이너 연결
  // (연결이 빠지면 show()가 조용히 무시되어 모든 알림이 울리지 않음)
  final container = ProviderContainer();
  NotificationService.init(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TaskManagerApp(),
    ),
  );
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
    // 테마 관련 값만 구독 (다른 설정이 바뀌어도 앱 전체를 다시 그리지 않도록)
    final settings = ref.watch(
      settingsProvider.select((s) {
        final v = s.value;
        return v == null
            ? null
            : (
                fontSize: v.fontSize,
                themeColor: v.themeColor,
                themeMode: v.themeMode,
              );
      }),
    );
    final fontSize = settings?.fontSize ?? AppFontSize.medium;
    final base = _fontSizeBase(fontSize);

    return MaterialApp(
      title: 'TaskManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appSeedColor,
        ).copyWith(primary: settings?.themeColor ?? appSeedColor),
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
        colorScheme: withDarkColors(
          ColorScheme.fromSeed(
            seedColor: appSeedColor,
            brightness: Brightness.dark,
          ).copyWith(primary: settings?.themeColor ?? appSeedColor),
        ),
        scaffoldBackgroundColor: darkBackground,
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
  final Set<String> _notifiedAlarmKeys = {};

  static const _navigationItems = [
    (Icons.note, '메모'),
    (Icons.calendar_month, '캘린더'),
    (Icons.mail, '메일'),
    (Icons.map, '지도'),
    (Icons.settings, '설정'),
  ];

  /// 메인 화면 좌측 네비게이션에 표시할 항목 목록 (선택된 아이콘은 테마색)
  List<NavigationRailDestination> _navigationDestinations(Color accent) => [
    for (final (icon, label) in _navigationItems)
      NavigationRailDestination(
        icon: Icon(icon, color: Colors.white),
        selectedIcon: Icon(icon, color: accent),
        label: Text(label),
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
    MemoEditorV2View(),
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
      await _quitApp();
    }
  }

  /// 종료: 트레이 아이콘을 먼저 치워 바로 꺼진 것처럼 보이게 함
  /// (창은 네이티브 쪽에서 엔진 정리 전에 숨김)
  Future<void> _quitApp() async {
    await _trayService.destroy();
    await windowManager.destroy();
  }

  // 트레이에서 복귀할 때 잠금 체크
  Future<void> _showWindow() async {
    final settings = ref.read(settingsProvider).value;
    // 이미 화면에 떠 있는 창(알림 클릭 등)은 다시 잠그지 않음
    if ((settings?.lockEnabled ?? false) && !await windowManager.isVisible()) {
      _lock();
    }
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  /// 잠금 화면 표시. 루트 네비게이터의 다이얼로그가 잠금 화면 위에 남지 않도록 먼저 닫음
  void _lock() {
    if (!mounted || _isLocked) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    setState(() => _isLocked = true);
  }

  /// 어디서든 빠른 메모 단축키(기본 Ctrl+Alt+M, 설정에서 변경):
  /// 빠른 메모 창 (트레이에 있었으면 저장 후 다시 트레이로)
  bool _quickMemoOpen = false;

  Future<void> _applyQuickMemoHotKey(String? spec) =>
      QuickMemoHotKeyService.instance.apply(
        QuickMemoShortcut.parse(spec ?? QuickMemoShortcut.defaultSpec),
      );

  Future<void> _openQuickMemo() async {
    if (_quickMemoOpen || !mounted) return;
    final wasVisible = await windowManager.isVisible();
    await _showWindow();
    // 잠금 화면이 떠 있으면 빠른 메모는 열지 않음
    if (_isLocked || !mounted) return;
    _quickMemoOpen = true;
    try {
      await showQuickMemoDialog(context);
    } finally {
      _quickMemoOpen = false;
    }
    if (!wasVisible) await windowManager.hide();
  }

  // 알람 알림 클릭: 트레이/최소화 상태에서도 창을 띄우고 해당 날짜의 캘린더로 이동
  // (잠금 중이면 잠금 해제 후 그 화면이 보임)
  Future<void> _openCalendarAt(DateTime date) async {
    if (!mounted) return;
    ref.read(currentMonthProvider.notifier)
      ..setYear(date.year)
      ..setMonth(date.month);
    ref.read(selectedDateProvider.notifier).select(date);
    ref.read(navigationProvider.notifier).navigateTo(1); // 캘린더 탭
    await _showWindow();
  }

  Timer? _alarmTimer;
  Timer? _focusModeTimer;
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();
    QuickMemoHotKeyService.instance.onPressed = _openQuickMemo;
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 첫 프레임 전에 화면이 교체(예: DB 오류 화면)됐으면 중단
      if (!mounted) return;
      // 알람 체커는 로그인 팝업과 무관하게 먼저 시작
      _startAlarmChecker();

      // 앱 시작 시 잠금 체크 (설정을 다 읽기 전이면 잠금이 빠지므로 기다림)
      AppSettings? settings;
      try {
        settings = await ref.read(settingsProvider.future);
      } catch (e) {
        print('설정 읽기 실패: $e');
      }
      if (!mounted) return;
      _applyQuickMemoHotKey(settings?.quickMemoHotKey);
      // 설정에서 단축키를 바꾸면 바로 다시 등록
      ref.listenManual(
        settingsProvider.select((s) => s.value?.quickMemoHotKey),
        (prev, next) {
          if (next != null && next != prev) _applyQuickMemoHotKey(next);
        },
      );
      // 설정한 시작 화면으로
      final startScreen = settings?.startScreen ?? 0;
      if (startScreen != 0) {
        ref.read(navigationProvider.notifier).navigateTo(startScreen);
      }
      if (settings?.lockEnabled ?? false) _lock();
      _checkForUpdate();

      // 휴지통 보관 기간이 지난 메모 정리 (기다리지 않음)
      ref
          .read(noteRepositoryProvider)
          .deleteExpiredNotes(days: settings?.trashRetentionDays ?? 30)
          .catchError((Object e) => print('휴지통 정리 실패: $e'));

      // 구글 로그인 여부 체크 — 오류가 나도 로그인 팝업은 띄움
      GoogleAccount? account;
      try {
        account = await ref.read(googleAccountProvider.future);
      } catch (e) {
        print('구글 계정 상태 확인 실패: $e');
      }
      if (account == null && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const GoogleLoginDialog(),
        );
      }

      // 로그인 상태가 반영된 메일 계정으로 폴링 시작
      try {
        final mailAccount = await ref.read(mailAccountProvider.future);
        if (mailAccount != null) {
          ref.read(mailCheckServiceProvider).start(mailAccount);
        }
      } catch (e) {
        print('메일 폴링 시작 실패: $e');
      }

      await _maybeShowDailyBriefing();
    });

    _startFocusModeChecker();
  }

  // 하루 첫 실행 때 오늘 브리핑 표시 (잠금 중이면 잠금 해제 후)
  Future<void> _maybeShowDailyBriefing() async {
    if (!mounted || _isLocked) return;
    if (!(ref.read(settingsProvider).value?.briefingAutoShow ?? true)) return;
    final db = ref.read(databaseProvider);
    if (!await claimDailyBriefing(db)) return;
    if (mounted) await showBriefingDialog(context);
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
        onClick: _showWindow,
      );
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _checkForUpdate() async {
    final service = UpdateService();
    final result = await service.checkForUpdate();
    // 지난번 업데이트가 설치되지 않았으면 같은 업데이트를 또 띄우지 않고 원인을 보여줌
    final failure = await service.takeUpdateFailure(result.downloadUrl ?? '');
    if (!mounted) return;
    if (failure != null) {
      showDialog(
        context: context,
        builder: (context) => _UpdateFailureDialog(failure: failure),
      );
      return;
    }
    if (!result.hasUpdate) return;

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
    _checkAlarms();
  }

  Future<void> _checkAlarms() async {
    final settings = ref.read(settingsProvider).value;
    if (!(settings?.notificationEnabled ?? true)) return;

    final db = ref.read(databaseProvider);
    final repo = EventRepository(db);
    final now = DateTime.now();
    // 알림은 시작 시각 이전에만 울리므로 오늘 이후 시작하는 일정만 조회
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final events = await repo.getUpcomingAlarmEvents(today);
    // 반복 일정은 알림이 울릴 수 있는 회차(오늘~모레, 최대 1일 전 알림)만 펼침
    final candidates = [
      for (final event in events)
        if (event.isRecurring)
          ...expandOccurrences(event, now, now.add(const Duration(days: 2)))
        else
          event,
    ];

    for (final event in candidates) {
      try {
        await _checkEventAlarm(event, now);
      } catch (e) {
        // 한 일정의 잘못된 데이터가 전체 알림을 막지 않도록
        print('알람 체크 실패 (${event.id}): $e');
      }
    }
  }

  Future<void> _checkEventAlarm(Event event, DateTime now) async {
    final eventDate = DateTime.parse(event.eventDate);

    // 시간 일정은 시작 시각, 하루종일 일정은 alarmTime(기본 09:00) 기준
    final time =
        event.startTime ??
        (event.alarmTime.isNotEmpty ? event.alarmTime : '09:00');
    final parts = time.split(':');
    final eventDateTime = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final alarmDateTime = eventDateTime.subtract(
      Duration(minutes: event.alarmDaysBefore),
    );

    final diff = alarmDateTime.difference(now).inMinutes;
    if (diff <= 0 && diff >= -1) {
      // 일정 시간이 바뀌면 다시 울릴 수 있도록 알람 시각까지 포함해 중복 체크
      final key = '${event.id}@${alarmDateTime.toIso8601String()}';
      if (!_notifiedAlarmKeys.add(key)) return;
      await NotificationService.show(
        title: '📅 일정 알람',
        body: event.title,
        onClick: () => _openCalendarAt(eventDate),
      );
    }
  }

  Future<void> _initTray() async {
    await _trayService.init(
      onShow: _showWindow, // 트레이 클릭 시 창을 보이고 잠금 상태를 체크합니다.
      onExit: _quitApp,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 잠금 화면
    if (_isLocked) {
      return LockScreen(
        onUnlocked: () {
          setState(() => _isLocked = false);
          // 잠금 때문에 미뤄둔 오늘 브리핑
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeShowDailyBriefing(),
          );
        },
      );
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
            leading: IconButton(
              tooltip: '오늘 브리핑',
              icon: const Icon(Icons.wb_sunny_outlined, color: Colors.white),
              onPressed: () => showBriefingDialog(context),
            ),
            destinations: _navigationDestinations(context.accent),
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
          VerticalDivider(width: 1, color: context.line),
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
    QuickMemoHotKeyService.instance
      ..onPressed = null
      ..apply(null);
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
    // 검색 필터와 무관하게 id로 찾아 선택 (없으면 선택 해제)
    final noteList = ref.read(noteListProvider.notifier);

    if (event.logicalKey == LogicalKeyboardKey.tab && !shift) {
      // Ctrl+Tab: 다음 탭
      final nextId = ids[(currentIndex + 1) % ids.length];
      ref.read(tabProvider.notifier).setActive(nextId);
      noteList.selectById(nextId);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab && shift) {
      // Ctrl+Shift+Tab: 이전 탭
      final prevId = ids[(currentIndex - 1 + ids.length) % ids.length];
      ref.read(tabProvider.notifier).setActive(prevId);
      noteList.selectById(prevId);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyW && !shift) {
      // Ctrl+W: 현재 탭 닫기
      if (tabState.activeNoteId == null) return false;
      ref.read(tabProvider.notifier).closeTab(tabState.activeNoteId!);
      final newState = ref.read(tabProvider).value;
      noteList.selectById(newState?.activeNoteId);
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
  final _service = UpdateService();
  bool _isDownloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await _service.downloadAndInstall(
        widget.result.downloadUrl!,
        widget.result.latestVersion!,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        // 취소는 오류로 보여주지 않음
        _error = e is UpdateCancelledException ? null : '$e';
      });
    }
  }

  @override
  void dispose() {
    if (_isDownloading) _service.cancel();
    super.dispose();
  }

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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ],
      ),
      actions: _isDownloading
          ? [TextButton(onPressed: _service.cancel, child: const Text('취소'))]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에'),
              ),
              ElevatedButton(
                onPressed: _install,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(_error == null ? '업데이트' : '다시 시도'),
              ),
            ],
    );
  }
}

/// 지난번 업데이트가 설치되지 않았을 때: 원인과 직접 설치 버튼
class _UpdateFailureDialog extends StatefulWidget {
  final UpdateFailure failure;
  const _UpdateFailureDialog({required this.failure});

  @override
  State<_UpdateFailureDialog> createState() => _UpdateFailureDialogState();
}

class _UpdateFailureDialogState extends State<_UpdateFailureDialog> {
  final _service = UpdateService();
  bool _isDownloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _installManually() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await _service.installManually(
        widget.failure,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _error = e is UpdateCancelledException ? null : '$e';
      });
    }
  }

  @override
  void dispose() {
    if (_isDownloading) _service.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failure = widget.failure;
    return AlertDialog(
      title: const Text('업데이트가 설치되지 않았습니다'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 버전: ${failure.currentVersion}'),
            Text('설치하려던 버전: ${failure.version}'),
            const SizedBox(height: 12),
            SelectableText(failure.reason, style: const TextStyle(height: 1.5)),
            if (failure.logPath != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                '설치 기록: ${failure.logPath}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? [TextButton(onPressed: _service.cancel, child: const Text('취소'))]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
              ElevatedButton(
                onPressed: _installManually,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('설치 화면으로 직접 설치'),
              ),
            ],
    );
  }
}
