import 'package:drift/drift.dart';

class Event {
  final int? id;
  final String title;
  final String eventDate;
  final String createdAt;
  final bool alarmEnabled;
  final String alarmTime;
  final int alarmDaysBefore;
  final bool isCompleted;
  final int priority;
  final String? googleEventId;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;
  final String? startDate;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final bool isAllDay;
  final String? content;
  final String? tagColor;

  // 반복: '' (없음) / daily / weekly / monthly / yearly — recurrence.dart 참고
  final String recurrence;
  // 반복 종료일 (yyyy-MM-dd, 포함). null이면 무기한
  final String? recurrenceUntil;

  // 구글에서 가져온 반복 일정의 회차일 때, 원본 일정의 구글 ID (DB에 저장 안 함)
  final String? googleRecurringEventId;

  bool get isRecurring => recurrence.isNotEmpty;

  const Event({
    this.id,
    required this.title,
    required this.eventDate,
    required this.createdAt,
    this.alarmEnabled = false,
    this.alarmTime = '09:00',
    this.alarmDaysBefore = 0,
    this.isCompleted = false,
    this.priority = 1,
    this.googleEventId,
    this.locationName,
    this.locationLat,
    this.locationLng,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.isAllDay = true,
    this.content,
    this.tagColor,
    this.recurrence = '',
    this.recurrenceUntil,
    this.googleRecurringEventId,
  });

  Event copyWith({
    int? id,
    String? title,
    String? eventDate,
    String? createdAt,
    bool? alarmEnabled,
    String? alarmTime,
    int? alarmDaysBefore,
    bool? isCompleted,
    int? priority,
    String? googleEventId,
    String? tagColor,
    String? startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    bool? isAllDay,
    String? content,
    String? recurrence,
    // 위치·반복 종료일은 null로 지울 수 있도록 Value<T> 패턴
    Value<String?> recurrenceUntil = const Value.absent(),
    Value<String?> locationName = const Value.absent(),
    Value<double?> locationLat = const Value.absent(),
    Value<double?> locationLng = const Value.absent(),
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmTime: alarmTime ?? this.alarmTime,
      alarmDaysBefore: alarmDaysBefore ?? this.alarmDaysBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      googleEventId: googleEventId ?? this.googleEventId,
      locationName: locationName.present
          ? locationName.value
          : this.locationName,
      locationLat: locationLat.present ? locationLat.value : this.locationLat,
      locationLng: locationLng.present ? locationLng.value : this.locationLng,
      tagColor: tagColor ?? this.tagColor,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      content: content ?? this.content,
      recurrence: recurrence ?? this.recurrence,
      recurrenceUntil: recurrenceUntil.present
          ? recurrenceUntil.value
          : this.recurrenceUntil,
      googleRecurringEventId: googleRecurringEventId,
    );
  }
}
