import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/map_repository.dart';
import '../providers/map_provider.dart';

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _mapController = MapController();

  static const _defaultCenter = LatLng(37.5665, 126.9780);
  static const _defaultZoom = 13.0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTags = ref.watch(activeMapTagsProvider);
    final placesAsync = ref.watch(mapPlaceProvider);
    final tagsAsync = ref.watch(mapTagProvider);
    final selectedLocation = ref.watch(selectedLocationProvider);

    ref.listen(selectedLocationProvider, (prev, next) {
      if (next != null) {
        _mapController.move(next.position, 15.0);
      }
    });

    final places = placesAsync.value ?? [];
    final tags = tagsAsync.value ?? [];

    final filteredPlaces = activeTags.isEmpty
        ? <MapPlace>[]
        : places.where((p) => activeTags.contains(p.tagId)).toList();

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.vworld.kr/req/wmts/1.0.0/8301697C-80F6-35C7-BCB2-F890D4B0409B/Base/{z}/{y}/{x}.png',
          userAgentPackageName: 'com.JH.taskmanager',
        ),
        // 저장된 장소 마커
        MarkerLayer(
          markers: filteredPlaces.map((place) {
            final tag = tags.firstWhere(
              (t) => t.id == place.tagId,
              orElse: () => MapTag(name: '', color: '#4A90E2'),
            );
            final color = Color(int.parse(tag.color.replaceFirst('#', '0xFF')));
            return Marker(
              point: LatLng(place.lat, place.lng),
              width: 40,
              height: 40,
              child: Tooltip(
                message: place.name,
                child: Icon(Icons.location_pin, color: color, size: 36),
              ),
            );
          }).toList(),
        ),
        // 검색 선택 마커
        if (selectedLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: selectedLocation.position,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFFE53935),
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
