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
    );
  }
}
