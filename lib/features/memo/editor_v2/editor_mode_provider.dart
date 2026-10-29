import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../views/memo_editor_view.dart';
import 'memo_editor_v2_view.dart';

const _settingKey = 'memo_editor_v2';

/// 새 메모 에디터 사용 여부 (설정에 저장, 기본: 사용).
/// 저장 형식이 같아 언제든 기존 에디터로 돌아갈 수 있음.
class NewMemoEditorNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals(_settingKey))).getSingleOrNull();
    return row?.value != 'false';
  }

  Future<void> set(bool enabled) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: _settingKey, value: '$enabled'),
        );
    state = AsyncData(enabled);
  }
}

final newMemoEditorProvider =
    AsyncNotifierProvider<NewMemoEditorNotifier, bool>(
      NewMemoEditorNotifier.new,
    );

/// 설정에 따라 새 에디터 또는 기존(appflowy) 에디터를 보여줌
class MemoEditorSwitcher extends ConsumerWidget {
  const MemoEditorSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useNew = ref.watch(newMemoEditorProvider).value;
    if (useNew == null) return const SizedBox.shrink();
    return useNew ? const MemoEditorV2View() : const MemoEditorView();
  }
}
