import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/memo/views/memo_list_view.dart';
import 'features/memo/views/memo_editor_view.dart';

void main() {
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

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 사이드바
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
          // 왼쪽 패널
          Container(
            width: 250,
            color: const Color(0xFFF5F5F5),
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                MemoListView(),
                Center(child: Text('캘린더')),
                Center(child: Text('메일')),
                Center(child: Text('설정')),
              ],
            ),
          ),
          // 구분선
          const VerticalDivider(width: 1, color: Color(0xFFDDDDDD)),
          // 오른쪽 메인 영역
          const Expanded(child: MemoEditorView()),
        ],
      ),
    );
  }
}
