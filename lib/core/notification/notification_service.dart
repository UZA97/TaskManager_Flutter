import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  static Future<void> init() async {
    await localNotifier.setup(
      appName: 'TaskManager',
    );
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    LocalNotification notification = LocalNotification(
      title: title,
      body: body,
    );
    await notification.show();
  }

  static Future<void> showAlarm(String eventTitle, DateTime date) async {
    await show(
      title: '📅 일정 알람',
      body: '${date.year}년 ${date.month}월 ${date.day}일 - $eventTitle',
    );
  }
}
