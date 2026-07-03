import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/notification/notification_service.dart';
import 'core/tray/tray_service.dart';
import 'features/memo/views/memo_list_view.dart';
import 'features/memo/views/memo_editor_view.dart';
import 'features/calendar/views/calendar_view.dart';
import 'features/calendar/views/calendar_editor_view.dart';
import 'features/mail/providers/mail_provider.dart';
import 'features/mail/services/mail_check_service.dart';
import 'features/settings/views/settings_view.dart';
import 'features/mail/views/mail_list_view.dart';
import 'features/mail/views/mail_detail_view.dart';
import 'features/map/views/map_view.dart';
import 'features/map/views/map_sidebar_view.dart';
import 'core/providers/navigation_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(950, 600),
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
  await NotificationService.init();

  runApp(const ProviderScope(child: TaskManagerApp()));
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90E2)),
        useMaterial3: true,
      ),
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

  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);
    _initTray();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initMailService();
  }

  Future<void> _initMailService() async {
    final container = ProviderScope.containerOf(context);
    final account = await container.read(mailAccountProvider.future);
    if (account != null) {
      container.read(mailCheckServiceProvider).start(account);
    }
  }

  @override
  void onWindowClose() async {
    // 트레이로 숨기기
    await windowManager.hide();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _trayService.destroy();
    super.dispose();
  }

  Future<void> _initTray() async {
    await _trayService.init(
      onShow: () async {
        await windowManager.show();
        await windowManager.focus();
      },
      onExit: () async {
        await windowManager.destroy();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
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
            color: const Color(0xFFF5F5F5),
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
                SizedBox(), // 4: 설정
              ],
            ),
          ),
        ],
      ),
    );
  }
}
