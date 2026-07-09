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
      dateFormat: switch (map['date_format']) {
        'iso' => AppDateFormat.iso,
        'us' => AppDateFormat.us,
        _ => AppDateFormat.korean,
      },
      timeFormat: switch (map['time_format']) {
        'h12' => AppTimeFormat.h12,
        _ => AppTimeFormat.h24,
      },
      lockEnabled: map['lock_enabled'] == 'true',
    );
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
    state = AsyncData(state.value!.copyWith(lockEnabled: enabled));
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

  // 날짜 형식
  Future<void> setDateFormat(AppDateFormat format) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'date_format', value: format.name),
        );
    state = AsyncData(state.value!.copyWith(dateFormat: format));
  }

  Future<void> setTimeFormat(AppTimeFormat format) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'time_format', value: format.name),
        );
    state = AsyncData(state.value!.copyWith(timeFormat: format));
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
    state = AsyncData(state.value!.copyWith(notificationEnabled: enabled));
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

  // 글꼴 크기
  Future<void> setFontSize(AppFontSize size) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'font_size', value: size.name),
        );
    state = AsyncData(state.value!.copyWith(fontSize: size));
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
