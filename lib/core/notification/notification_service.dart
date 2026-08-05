import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import '../settings/app_settings.dart';
import '../settings/settings_provider.dart';

class NotificationService {
  static ProviderContainer? _container;

  static void init(ProviderContainer container) {
    _container = container;
  }

  static Future<void> setup() async {
    await localNotifier.setup(appName: 'TaskManager');
  }

  static bool _isInFocusMode(AppSettings settings) {
    if (!settings.focusModeEnabled) return false;

    final now = TimeOfDay.now();
    final start = _parseTime(settings.focusModeStart);
    final end = _parseTime(settings.focusModeEnd);

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // 자정 넘어가는 경우 (예: 22:00 ~ 08:00)
    if (startMinutes > endMinutes) {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
    // 일반 경우 (예: 09:00 ~ 18:00)
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    final settings = _container?.read(settingsProvider).value;
    if (settings == null) return;

    // 알림 비활성화 체크
    if (!settings.notificationEnabled) return;

    // 집중모드 체크
    if (_isInFocusMode(settings)) return;

    final notification = LocalNotification(title: title, body: body);
    await notification.show();
  }

  static Future<void> showAlarm(String eventTitle, DateTime date) async {
    await show(
      title: '📅 일정 알람',
      body: '${date.year}년 ${date.month}월 ${date.day}일 - $eventTitle',
    );
  }
}
