import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/map_repository.dart';
import '../services/location_search_result.dart';

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

// 음식점 목록
class NearbyRestaurantsNotifier extends Notifier<List<LocationSearchResult>> {
  @override
  List<LocationSearchResult> build() => [];

  void setRestaurants(List<LocationSearchResult> results) => state = results;
  void clear() => state = [];
}

final nearbyRestaurantsProvider =
    NotifierProvider<NearbyRestaurantsNotifier, List<LocationSearchResult>>(
      NearbyRestaurantsNotifier.new,
    );

// 음식점 표시 여부
class ShowRestaurantsNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

// 검색 결과 마커
class SearchResultsNotifier extends Notifier<List<LocationSearchResult>> {
  @override
  List<LocationSearchResult> build() => [];

  void setResults(List<LocationSearchResult> results) => state = results;
  void clear() => state = [];
}

final searchResultsProvider =
    NotifierProvider<SearchResultsNotifier, List<LocationSearchResult>>(
      SearchResultsNotifier.new,
    );

// 활성화된 카테고리
class ActiveCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? code) => state = code;
}

final activeCategoryProvider =
    NotifierProvider<ActiveCategoryNotifier, String?>(
      ActiveCategoryNotifier.new,
    );
