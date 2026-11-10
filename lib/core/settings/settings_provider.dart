import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import 'app_settings.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    // 앱 설정을 데이터베이스에서 읽어 초기 상태를 구성합니다.
    final db = ref.watch(databaseProvider);
    final rows = await db.select(db.settingTable).get();
    final map = {for (final r in rows) r.key: r.value};

    return AppSettings(
      trayModeEnabled: map['tray_mode_enabled'] != 'false',
      notificationEnabled: map['notification_enabled'] != 'false',
      themeMode: map['theme_mode'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      themeColor: map['theme_color'] != null
          ? Color(int.parse(map['theme_color']!))
          : const Color(0xFF4A90E2),
      fontSize: map['font_size'] == 'small'
          ? AppFontSize.small
          : map['font_size'] == 'large'
          ? AppFontSize.large
          : AppFontSize.medium,
      lockEnabled: map['lock_enabled'] == 'true',

      focusModeEnabled: map['focus_mode_enabled'] == 'true',
      focusModeStart: map['focus_mode_start'] ?? "22:00",
      focusModeEnd: map['focus_mode_end'] ?? "08:00",
      startScreen: (int.tryParse(map['start_screen'] ?? '') ?? 0).clamp(0, 3),
      briefingAutoShow: map['briefing_auto_show'] != 'false',
      trashRetentionDays: int.tryParse(map['trash_retention_days'] ?? '') ?? 30,
      quickMemoHotKey: map['quick_memo_hotkey'] ?? 'control,alt|M',
    );
  }

  Future<void> setFocusMode(bool enabled) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'focus_mode_enabled',
            value: enabled.toString(),
          ),
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(focusModeEnabled: enabled));
  }

  Future<void> setFocusModeStart(String time) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'focus_mode_start', value: time),
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(focusModeStart: time));
  }

  Future<void> setFocusModeEnd(String time) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'focus_mode_end', value: time),
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(focusModeEnd: time));
  }

  Future<void> setLockEnabled(bool enabled) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'lock_enabled',
            value: enabled.toString(),
          ),
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(lockEnabled: enabled));
  }

  Future<void> setPassword(String password) async {
    final db = ref.read(databaseProvider);
    final hash = sha256.convert(utf8.encode(password)).toString();
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'lock_password', value: hash),
        );
  }

  Future<bool> verifyPassword(String password) async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('lock_password'))).getSingleOrNull();
    if (row == null) return false;
    final hash = sha256.convert(utf8.encode(password)).toString();
    return row.value == hash;
  }

  // 알림모드 설정
  Future<void> setNotificationEnabled(bool enabled) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'notification_enabled',
            value: enabled.toString(),
          ),
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(notificationEnabled: enabled));
  }

  // 트레이 모드 설정
  Future<void> _put(String key, String value) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: key, value: value),
        );
  }

  // 시작 화면
  Future<void> setStartScreen(int index) async {
    await _put('start_screen', '$index');
    state = AsyncData(state.requireValue.copyWith(startScreen: index));
  }

  // 오늘 브리핑 자동 표시
  Future<void> setBriefingAutoShow(bool enabled) async {
    await _put('briefing_auto_show', '$enabled');
    state = AsyncData(state.requireValue.copyWith(briefingAutoShow: enabled));
  }

  // 휴지통 보관 기간 (0이면 자동으로 비우지 않음)
  Future<void> setTrashRetentionDays(int days) async {
    await _put('trash_retention_days', '$days');
    state = AsyncData(state.requireValue.copyWith(trashRetentionDays: days));
  }

  // 빠른 메모 단축키 (QuickMemoShortcut.spec, 'off'면 사용 안 함)
  Future<void> setQuickMemoHotKey(String spec) async {
    await _put('quick_memo_hotkey', spec);
    state = AsyncData(state.requireValue.copyWith(quickMemoHotKey: spec));
  }

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
    final current = state.requireValue;
    state = AsyncData(current.copyWith(trayModeEnabled: enabled));
  }

  // 글꼴 크기
  Future<void> setFontSize(AppFontSize size) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'font_size', value: size.name),
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(fontSize: size));
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
    final current = state.requireValue;
    state = AsyncData(current.copyWith(themeMode: mode));
  }

  // 테마 색상 설정
  // 테마 색상을 저장하고 즉시 상태에 반영합니다.
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
    final current = state.requireValue;
    state = AsyncData(current.copyWith(themeColor: color));
  }

  Future<bool> hasPassword() async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('lock_password'))).getSingleOrNull();
    return row != null;
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
