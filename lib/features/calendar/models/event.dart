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
    // 위치 필드만 Value<T> 패턴
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
    );
  }
}
