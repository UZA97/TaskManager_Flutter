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

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WindowListener {
  final _trayService = TrayService();
  bool _isLocked = false;

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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.note, color: Colors.white),
                selectedIcon: Icon(Icons.note, color: Color(0xFF4A90E2)),
                label: Text('메모'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month, color: Colors.white),
                selectedIcon: Icon(
                  Icons.calendar_month,
                  color: Color(0xFF4A90E2),
                ),
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
            ],
          ),
          Container(
            width: 250,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: IndexedStack(
              index: ref.watch(navigationProvider),
              children: const [
                MemoListView(), // 0: 메모
                CalendarView(), // 1: 캘린더
                MailListView(), // 2: 메일
                MapSidebarView(), // 3: 지도 (새로 만들 거)
                SettingsView(), // 4: 설정
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFFDDDDDD)),
          Expanded(
            child: IndexedStack(
              index: ref.watch(navigationProvider),
              children: const [
                MemoEditorView(), // 0: 메모
                CalendarEditorView(), // 1: 캘린더
                MailDetailView(), // 2: 메일
                MapView(), // 3: 지도 (새로 만들 거)
                SettingsDetailView(), // 4: 설정
              ],
            ),
          ),
        ],
      ),
    );
  }
}
