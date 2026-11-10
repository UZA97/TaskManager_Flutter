import 'package:flutter/material.dart';

enum AppFontSize { small, medium, large }

class AppSettings {
  final bool trayModeEnabled;
  final ThemeMode themeMode;
  final Color themeColor;
  final AppFontSize fontSize;
  final bool notificationEnabled;
  final bool lockEnabled;
  final bool focusModeEnabled;
  final String focusModeStart; // "22:00"
  final String focusModeEnd; // "08:00"
  final int startScreen; // 앱을 켰을 때 화면 (0 메모, 1 캘린더, 2 메일, 3 지도)
  final bool briefingAutoShow; // 하루 첫 실행 때 오늘 브리핑 띄우기
  final int trashRetentionDays; // 휴지통 보관 기간 (0이면 자동으로 비우지 않음)
  final String quickMemoHotKey; // 빠른 메모 단축키 (QuickMemoShortcut.spec, "off"면 사용 안 함)

  const AppSettings({
    this.trayModeEnabled = true,
    this.themeMode = ThemeMode.light,
    this.themeColor = const Color(0xFF4A90E2),
    this.fontSize = AppFontSize.medium,
    this.notificationEnabled = true,
    this.lockEnabled = false,
    this.focusModeEnabled = false,
    this.focusModeStart = "22:00",
    this.focusModeEnd = "08:00",
    this.startScreen = 0,
    this.briefingAutoShow = true,
    this.trashRetentionDays = 30,
    this.quickMemoHotKey = 'control,alt|M',
  });

  AppSettings copyWith({
    bool? trayModeEnabled,
    ThemeMode? themeMode,
    Color? themeColor,
    AppFontSize? fontSize,
    bool? notificationEnabled,
    bool? lockEnabled,
    bool? focusModeEnabled,
    String? focusModeStart,
    String? focusModeEnd,
    int? startScreen,
    bool? briefingAutoShow,
    int? trashRetentionDays,
    String? quickMemoHotKey,
  }) {
    return AppSettings(
      trayModeEnabled: trayModeEnabled ?? this.trayModeEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      fontSize: fontSize ?? this.fontSize,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      focusModeStart: focusModeStart ?? this.focusModeStart,
      focusModeEnd: focusModeEnd ?? this.focusModeEnd,
      startScreen: startScreen ?? this.startScreen,
      briefingAutoShow: briefingAutoShow ?? this.briefingAutoShow,
      trashRetentionDays: trashRetentionDays ?? this.trashRetentionDays,
      quickMemoHotKey: quickMemoHotKey ?? this.quickMemoHotKey,
    );
  }
}
