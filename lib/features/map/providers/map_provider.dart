import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/map_repository.dart';

class SelectedLocation {
  final String name;
  final LatLng position;
  const SelectedLocation({required this.name, required this.position});
}

class SelectedLocationNotifier extends Notifier<SelectedLocation?> {
  @override
  SelectedLocation? build() => null;
  void select(SelectedLocation? location) => state = location;
}

final selectedLocationProvider =
    NotifierProvider<SelectedLocationNotifier, SelectedLocation?>(
      SelectedLocationNotifier.new,
    );

// 활성화된 태그 필터
class ActiveMapTagsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void toggle(int tagId) {
    final current = Set<int>.from(state);
    if (current.contains(tagId)) {
      current.remove(tagId);
    } else {
      current.add(tagId);
    }
    state = current;
  }

  void clear() => state = {};
}

final activeMapTagsProvider = NotifierProvider<ActiveMapTagsNotifier, Set<int>>(
  ActiveMapTagsNotifier.new,
);

// 태그 목록
class MapTagNotifier extends AsyncNotifier<List<MapTag>> {
  @override
  Future<List<MapTag>> build() async {
    final repo = ref.watch(mapRepositoryProvider);
    return repo.getAllTags();
  }

  Future<void> createTag(String name, String color) async {
    final repo = ref.read(mapRepositoryProvider);
    await repo.createTag(name, color);
    ref.invalidateSelf();
  }

  Future<void> deleteTag(int id) async {
    final repo = ref.read(mapRepositoryProvider);
    await repo.deleteTag(id);
    ref.read(activeMapTagsProvider.notifier).clear();
    ref.invalidateSelf();
  }
}

final mapTagProvider = AsyncNotifierProvider<MapTagNotifier, List<MapTag>>(
  MapTagNotifier.new,
);

// 장소 목록
class MapPlaceNotifier extends AsyncNotifier<List<MapPlace>> {
  @override
  Future<List<MapPlace>> build() async {
    final repo = ref.watch(mapRepositoryProvider);
    return repo.getAllPlaces();
  }

  Future<void> addPlace(MapPlace place) async {
    final repo = ref.read(mapRepositoryProvider);
    await repo.addPlace(place);
    ref.invalidateSelf();
  }

  Future<void> deletePlace(int id) async {
    final repo = ref.read(mapRepositoryProvider);
    await repo.deletePlace(id);
    ref.invalidateSelf();
  }
}

final mapPlaceProvider =
    AsyncNotifierProvider<MapPlaceNotifier, List<MapPlace>>(
      MapPlaceNotifier.new,
    );
