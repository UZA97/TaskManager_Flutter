import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import '../settings/settings_provider.dart';

class NotificationService {
  static ProviderContainer? _container;

  static void init(ProviderContainer container) {
    _container = container;
  }

  static Future<void> setup() async {
    await localNotifier.setup(appName: 'TaskManager');
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    final enabled =
        _container?.read(settingsProvider).value?.notificationEnabled ?? true;
    if (!enabled) return;

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
