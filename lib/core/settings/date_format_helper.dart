import 'app_settings.dart';

class DateFormatHelper {
  static String formatDate(String isoDate, AppDateFormat format) {
    final date = DateTime.parse(isoDate);
    return switch (format) {
      AppDateFormat.iso =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      AppDateFormat.korean => '${date.year}년 ${date.month}월 ${date.day}일',
      AppDateFormat.us =>
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}',
    };
  }

  static String formatTime(DateTime date, AppTimeFormat format) {
    return switch (format) {
      AppTimeFormat.h24 =>
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      AppTimeFormat.h12 => () {
        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final period = date.hour < 12 ? 'AM' : 'PM';
        return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
      }(),
    };
  }
}
