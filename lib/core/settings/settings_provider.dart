import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import 'app_settings.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final db = ref.watch(databaseProvider);
    final rows = await db.select(db.settingTable).get();
    final map = {for (final r in rows) r.key: r.value};

    return AppSettings(
      trayModeEnabled: map['tray_mode_enabled'] != 'false',
      themeMode: map['theme_mode'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      themeColor: map['theme_color'] != null
          ? Color(int.parse(map['theme_color']!))
          : const Color(0xFF4A90E2),
    );
  }

  // 트레이 모드 설정
  Future<void> setTrayMode(bool enabled) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'tray_mode_enabled',
            value: enabled.toString(),
          ),
        );
    state = AsyncData(state.value!.copyWith(trayModeEnabled: enabled));
  }

  // 테마 모드 설정
  Future<void> setThemeMode(ThemeMode mode) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'theme_mode',
            value: mode == ThemeMode.dark ? 'dark' : 'light',
          ),
        );
    state = AsyncData(state.value!.copyWith(themeMode: mode));
  }

  // 테마 색상 설정
  Future<void> setThemeColor(Color color) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'theme_color',
            value: color.value.toString(),
          ),
        );
    state = AsyncData(state.value!.copyWith(themeColor: color));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
