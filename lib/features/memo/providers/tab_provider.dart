import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

class TabState {
  final List<int> tabNoteIds;
  final int? activeNoteId;

  const TabState({this.tabNoteIds = const [], this.activeNoteId});

  TabState copyWith({
    List<int>? tabNoteIds,
    int? activeNoteId,
    bool clearActive = false,
  }) {
    return TabState(
      tabNoteIds: tabNoteIds ?? this.tabNoteIds,
      activeNoteId: clearActive ? null : activeNoteId ?? this.activeNoteId,
    );
  }

  Map<String, dynamic> toJson() => {
    'tabs': tabNoteIds,
    'activeId': activeNoteId,
  };

  factory TabState.fromJson(Map<String, dynamic> json) => TabState(
    tabNoteIds: (json['tabs'] as List<dynamic>).cast<int>(),
    activeNoteId: json['activeId'] as int?,
  );
}

class TabNotifier extends AsyncNotifier<TabState> {
  @override
  Future<TabState> build() async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('tab_state'))).getSingleOrNull();
    if (row == null) return const TabState();
    try {
      return TabState.fromJson(jsonDecode(row.value));
    } catch (_) {
      return const TabState();
    }
  }

  Future<void> _save(TabState state) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'tab_state',
            value: jsonEncode(state.toJson()),
          ),
        );
  }

  // 탭 추가
  Future<void> addTab(int noteId) async {
    final current = state.value ?? const TabState();
    if (current.tabNoteIds.contains(noteId)) {
      // 이미 열려있으면 활성화만
      await setActive(noteId);
      return;
    }
    final next = current.copyWith(
      tabNoteIds: [...current.tabNoteIds, noteId],
      activeNoteId: noteId,
    );
    state = AsyncData(next);
    await _save(next);
  }

  // 탭 닫기
  Future<void> closeTab(int noteId) async {
    final current = state.value ?? const TabState();
    final newTabs = current.tabNoteIds.where((id) => id != noteId).toList();

    int? newActive;
    if (current.activeNoteId == noteId) {
      // 닫힌 탭이 활성 탭이면 이전 탭 활성화
      final idx = current.tabNoteIds.indexOf(noteId);
      if (newTabs.isNotEmpty) {
        newActive = newTabs[idx > 0 ? idx - 1 : 0];
      }
    } else {
      newActive = current.activeNoteId;
    }

    final next = TabState(tabNoteIds: newTabs, activeNoteId: newActive);
    state = AsyncData(next);
    await _save(next);
  }

  // 활성 탭 변경
  Future<void> setActive(int noteId) async {
    final current = state.value ?? const TabState();
    final next = current.copyWith(activeNoteId: noteId);
    state = AsyncData(next);
    await _save(next);
  }

  // 탭 순서 변경 (드래그)
  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value ?? const TabState();
    final tabs = List<int>.from(current.tabNoteIds);
    final item = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, item);
    final next = current.copyWith(tabNoteIds: tabs);
    state = AsyncData(next);
    await _save(next);
  }
}

final tabProvider = AsyncNotifierProvider<TabNotifier, TabState>(
  TabNotifier.new,
);
