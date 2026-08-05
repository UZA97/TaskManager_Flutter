import 'package:flutter/material.dart';

enum AppDateFormat { iso, korean, us }

enum AppTimeFormat { h24, h12 }

enum AppFontSize { small, medium, large }

class AppSettings {
  final bool trayModeEnabled;
  final ThemeMode themeMode;
  final Color themeColor;
  final AppFontSize fontSize;
  final bool notificationEnabled;
  final AppDateFormat dateFormat;
  final AppTimeFormat timeFormat;
  final bool lockEnabled;
  final bool focusModeEnabled;
  final String focusModeStart; // "22:00"
  final String focusModeEnd; // "08:00"

  const AppSettings({
    this.trayModeEnabled = true,
    this.themeMode = ThemeMode.light,
    this.themeColor = const Color(0xFF4A90E2),
    this.fontSize = AppFontSize.medium,
    this.notificationEnabled = true,
    this.dateFormat = AppDateFormat.korean,
    this.timeFormat = AppTimeFormat.h24,
    this.lockEnabled = false,
    this.focusModeEnabled = false,
    this.focusModeStart = "22:00",
    this.focusModeEnd = "08:00",
  });

  AppSettings copyWith({
    bool? trayModeEnabled,
    ThemeMode? themeMode,
    Color? themeColor,
    AppFontSize? fontSize,
    bool? notificationEnabled,
    AppDateFormat? dateFormat,
    AppTimeFormat? timeFormat,
    bool? lockEnabled,
    bool? focusModeEnabled,
    String? focusModeStart,
    String? focusModeEnd,
  }) {
    return AppSettings(
      trayModeEnabled: trayModeEnabled ?? this.trayModeEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      fontSize: fontSize ?? this.fontSize,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      focusModeStart: focusModeStart ?? this.focusModeStart,
      focusModeEnd: focusModeEnd ?? this.focusModeEnd,
    );
  }
}
