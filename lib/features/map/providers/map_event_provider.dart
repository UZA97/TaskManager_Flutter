import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../calendar/data/event_repository.dart';
import '../../calendar/models/event.dart';

/// 지도에 일정 마커 표시 여부
class ShowEventsOnMapNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final showEventsOnMapProvider = NotifierProvider<ShowEventsOnMapNotifier, bool>(
  ShowEventsOnMapNotifier.new,
);

/// 같은 장소의 일정 묶음 (마커 하나)
class EventPlace {
  final LatLng position;
  final String? name;
  final List<Event> events; // 날짜순

  const EventPlace({required this.position, this.name, required this.events});
}

/// 지도에 표시할 일정 기간 (오늘부터)
const mapEventDays = 30;

/// 앞으로 [mapEventDays]일 동안 장소 좌표가 있는 일정을 장소별로 묶음.
/// 지도 탭을 열 때마다 새로 조회 (autoDispose).
final mapEventPlacesProvider = FutureProvider.autoDispose<List<EventPlace>>((
  ref,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final events = await ref
      .read(eventRepositoryProvider)
      .getEventsInRange(today, today.add(const Duration(days: mapEventDays)));
  return groupEventsByPlace(events);
});

/// 좌표가 있는 일정만, 같은 좌표(약 1m 단위)끼리 묶음
List<EventPlace> groupEventsByPlace(List<Event> events) {
  final groups = <String, List<Event>>{};
  for (final e in events) {
    final lat = e.locationLat;
    final lng = e.locationLng;
    if (lat == null || lng == null) continue;
    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    groups.putIfAbsent(key, () => []).add(e);
  }
  return groups.values.map((list) {
    list.sort((a, b) {
      final byDate = a.eventDate.compareTo(b.eventDate);
      return byDate != 0
          ? byDate
          : (a.startTime ?? '').compareTo(b.startTime ?? '');
    });
    final first = list.first;
    return EventPlace(
      position: LatLng(first.locationLat!, first.locationLng!),
      name: first.locationName,
      events: list,
    );
  }).toList();
}
