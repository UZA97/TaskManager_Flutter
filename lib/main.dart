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

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();

    // 앱 시작 시 잠금 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider).value;
      if (settings?.lockEnabled ?? false) {
        setState(() => _isLocked = true);
      }
    });
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
            child: IndexedStack(
              index: ref.watch(navigationProvider),
              children: _sidePanels,
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFFDDDDDD)),
          Expanded(
            child: IndexedStack(
              index: ref.watch(navigationProvider),
              children: _detailPanels,
            ),
          ),
        ],
      ),
    );
  }
}
