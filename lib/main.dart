import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/notification/notification_service.dart';
import 'core/tray/tray_service.dart';
import 'features/memo/views/memo_list_view.dart';
import 'features/memo/views/memo_editor_view.dart';
import 'features/calendar/views/calendar_view.dart';
import 'features/calendar/views/calendar_editor_view.dart';
import 'features/mail/views/mail_settings_view.dart';
import 'features/mail/providers/mail_provider.dart';
import 'features/mail/services/mail_check_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 순서 중요: window_manager 먼저
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

  // 알림은 window 다음
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

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WindowListener {
  int _selectedIndex = 0;
  final _trayService = TrayService();
  bool _mailServiceInitialized = false;

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
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
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
              index: _selectedIndex,
              children: const [
                MemoListView(),
                CalendarView(),
                MailSettingsView(),
                Center(child: Text('설정')),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFFDDDDDD)),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                MemoEditorView(),
                CalendarEditorView(),
                Center(child: Text('메일')),
                Center(child: Text('설정')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
