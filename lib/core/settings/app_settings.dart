import 'package:flutter/material.dart';

enum AppFontSize { small, medium, large }

class AppSettings {
  final bool trayModeEnabled;
  final bool notificationEnabled;
  final ThemeMode themeMode;
  final Color themeColor;
  final AppFontSize fontSize;

  const AppSettings({
    this.trayModeEnabled = true,
    this.themeMode = ThemeMode.light,
    this.themeColor = const Color(0xFF4A90E2),
    this.fontSize = AppFontSize.medium,
    this.notificationEnabled = true,
  });

  AppSettings copyWith({
    bool? trayModeEnabled,
    ThemeMode? themeMode,
    Color? themeColor,
    AppFontSize? fontSize,
    bool? notificationEnabled,
  }) {
    return AppSettings(
      trayModeEnabled: trayModeEnabled ?? this.trayModeEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      fontSize: fontSize ?? this.fontSize,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }
}
