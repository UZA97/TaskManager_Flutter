import 'package:flutter/material.dart';

class AppSettings {
  final bool trayModeEnabled;
  final ThemeMode themeMode;
  final Color themeColor;

  const AppSettings({
    this.trayModeEnabled = true,
    this.themeMode = ThemeMode.light,
    this.themeColor = const Color(0xFF4A90E2),
  });

  AppSettings copyWith({
    bool? trayModeEnabled,
    ThemeMode? themeMode,
    Color? themeColor,
  }) {
    return AppSettings(
      trayModeEnabled: trayModeEnabled ?? this.trayModeEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
    );
  }
}
