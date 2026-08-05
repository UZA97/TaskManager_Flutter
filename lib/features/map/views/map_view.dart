import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/map_provider.dart';
import '../data/map_repository.dart';
import '../services/kakao_local_service.dart';
import '../services/location_search_result.dart';

// 카테고리 정의
class _MapCategory {
  final String code;
  final String label;
  final IconData icon;
  final Color color;

  const _MapCategory({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _categories = [
  _MapCategory(
    code: 'FD6',
    label: '음식점',
    icon: Icons.restaurant,
    color: Color(0xFFFF5722),
  ),
  _MapCategory(
    code: 'CE7',
    label: '카페',
    icon: Icons.coffee,
    color: Color(0xFF795548),
  ),
  _MapCategory(
    code: 'CS2',
    label: '편의점',
    icon: Icons.store,
    color: Color(0xFF4CAF50),
  ),
  _MapCategory(
    code: 'HP8',
    label: '병원',
    icon: Icons.local_hospital,
    color: Color(0xFFE53935),
  ),
  _MapCategory(
    code: 'PM9',
    label: '약국',
    icon: Icons.local_pharmacy,
    color: Color(0xFF9C27B0),
  ),
  _MapCategory(
    code: 'BK9',
    label: '은행',
    icon: Icons.account_balance,
    color: Color(0xFF1565C0),
  ),
  _MapCategory(
    code: 'SW8',
    label: '지하철',
    icon: Icons.subway,
    color: Color(0xFF0097A7),
  ),
  _MapCategory(
    code: 'PK6',
    label: '주차장',
    icon: Icons.local_parking,
    color: Color(0xFF607D8B),
  ),
  _MapCategory(
    code: 'OL7',
    label: '주유소',
    icon: Icons.local_gas_station,
    color: Color(0xFFFF9800),
  ),
  _MapCategory(
    code: 'AT4',
    label: '관광',
    icon: Icons.photo_camera,
    color: Color(0xFF8BC34A),
  ),
  _MapCategory(
    code: 'AD5',
    label: '숙박',
    icon: Icons.hotel,
    color: Color(0xFF3F51B5),
  ),
  _MapCategory(
    code: 'CT1',
    label: '문화시설',
    icon: Icons.museum,
    color: Color(0xFFE91E63),
  ),
];

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _mapController = MapController();
  static const _defaultCenter = LatLng(37.5665, 126.9780);
  static const _defaultZoom = 13.0;
  static const _minZoom = 6.0;
  static const _maxZoom = 19.0;
  bool _isLoadingCategory = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _toggleCategory(String code) async {
    final current = ref.read(activeCategoryProvider);

    // 같은 카테고리 누르면 해제
    if (current == code) {
      ref.read(activeCategoryProvider.notifier).set(null);
      ref.read(nearbyRestaurantsProvider.notifier).clear();
      return;
    }

    setState(() => _isLoadingCategory = true);

    try {
      final center = _mapController.camera.center;
      final results = await KakaoLocalService().searchByCategory(
        categoryCode: code,
        lat: center.latitude,
        lng: center.longitude,
        radius: 2000,
      );
      ref.read(nearbyRestaurantsProvider.notifier).setRestaurants(results);
      ref.read(activeCategoryProvider.notifier).set(code);
    } catch (e) {
      // 실패 무시
    } finally {
      setState(() => _isLoadingCategory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTags = ref.watch(activeMapTagsProvider);
    final placesAsync = ref.watch(mapPlaceProvider);
    final tagsAsync = ref.watch(mapTagProvider);
    // final selectedLocation = ref.watch(selectedLocationProvider);
    final categoryResults = ref.watch(nearbyRestaurantsProvider);
    final activeCategory = ref.watch(activeCategoryProvider);
    final searchResults = ref.watch(searchResultsProvider);

    ref.listen(selectedLocationProvider, (prev, next) {
      if (next != null) {
        _mapController.move(next.position, _maxZoom);
      }
    });

    final places = placesAsync.value ?? [];
    final tags = tagsAsync.value ?? [];
    final filteredPlaces = activeTags.isEmpty
        ? <MapPlace>[]
        : places.where((p) => activeTags.contains(p.tagId)).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: _defaultZoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            cameraConstraint: CameraConstraint.containCenter(
              bounds: LatLngBounds(
                const LatLng(35.75, 125.4), // 남서
                const LatLng(40.4, 132), // 북동
              ),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.vworld.kr/req/wmts/1.0.0/8301697C-80F6-35C7-BCB2-F890D4B0409B/Base/{z}/{y}/{x}.png',
              userAgentPackageName: 'com.JH.taskmanager',
            ),

            // 저장된 장소 마커
            if (filteredPlaces.isNotEmpty)
              MarkerLayer(
                markers: filteredPlaces.map((place) {
                  final tag = tags.firstWhere(
                    (t) => t.id == place.tagId,
                    orElse: () => MapTag(name: '', color: '#4A90E2'),
                  );
                  final color = Color(
                    int.parse(tag.color.replaceFirst('#', '0xFF')),
                  );
                  return Marker(
                    point: LatLng(place.lat, place.lng),
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedLocationProvider.notifier)
                            .select(
                              SelectedLocation(
                                name: place.name,
                                position: LatLng(place.lat, place.lng),
                              ),
                            );
                        _mapController.move(
                          LatLng(place.lat, place.lng),
                          _maxZoom,
                        );
                      },
                      child: _HoverMarker(
                        tooltip: place.name,
                        size: 28,
                        onTap: () {
                          ref
                              .read(selectedLocationProvider.notifier)
                              .select(
                                SelectedLocation(
                                  name: place.name,
                                  position: LatLng(place.lat, place.lng),
                                ),
                              );
                          _mapController.move(
                            LatLng(place.lat, place.lng),
                            16.0,
                          );
                        },
                        child: Icon(Icons.location_pin, color: color, size: 28),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // 카테고리 검색 결과 마커
            if (activeCategory != null && categoryResults.isNotEmpty)
              MarkerLayer(
                markers: categoryResults.map((r) {
                  final cat = _categories.firstWhere(
                    (c) => c.code == activeCategory,
                    orElse: () => _categories.first,
                  );
                  return Marker(
                    point: LatLng(r.lat, r.lng),
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedLocationProvider.notifier)
                            .select(
                              SelectedLocation(
                                name: r.name,
                                position: LatLng(r.lat, r.lng),
                              ),
                            );
                        _mapController.move(LatLng(r.lat, r.lng), _maxZoom);
                      },
                      child: _HoverMarker(
                        tooltip: r.name,
                        size: 22,
                        onTap: () {
                          ref
                              .read(selectedLocationProvider.notifier)
                              .select(
                                SelectedLocation(
                                  name: r.name,
                                  position: LatLng(r.lat, r.lng),
                                ),
                              );
                          _mapController.move(LatLng(r.lat, r.lng), _maxZoom);
                        },
                        child: Icon(cat.icon, color: cat.color, size: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // 검색 결과 마커
            if (searchResults.isNotEmpty)
              MarkerLayer(
                markers: searchResults.map((r) {
                  return Marker(
                    point: LatLng(r.lat, r.lng),
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedLocationProvider.notifier)
                            .select(
                              SelectedLocation(
                                name: r.name,
                                position: LatLng(r.lat, r.lng),
                              ),
                            );
                        _mapController.move(LatLng(r.lat, r.lng), _maxZoom);
                      },
                      child: _HoverMarker(
                        tooltip: r.name,
                        size: 22,
                        onTap: () {
                          ref
                              .read(selectedLocationProvider.notifier)
                              .select(
                                SelectedLocation(
                                  name: r.name,
                                  position: LatLng(r.lat, r.lng),
                                ),
                              );
                          _mapController.move(LatLng(r.lat, r.lng), _maxZoom);
                        },
                        child: const Icon(
                          Icons.place,
                          color: Color(0xFF4A90E2),
                          size: 22,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // 선택된 위치 마커
            // if (selectedLocation != null)
            //   MarkerLayer(
            //     markers: [
            //       Marker(
            //         point: selectedLocation.position,
            //         width: 40,
            //         height: 40,
            //         child: const Icon(
            //           Icons.location_pin,
            //           color: Color(0xFFE53935),
            //           size: 40,
            //         ),
            //       ),
            //     ],
            //   ),
          ],
        ),

        // 좌상단 카테고리 버튼들
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isActive = activeCategory == cat.code;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: _isLoadingCategory
                        ? null
                        : () => _toggleCategory(cat.code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? cat.color : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingCategory && isActive)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              cat.icon,
                              size: 13,
                              color: isActive ? Colors.white : cat.color,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : cat.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverMarker extends StatefulWidget {
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final String tooltip;

  const _HoverMarker({
    required this.child,
    required this.size,
    this.onTap,
    required this.tooltip,
  });

  @override
  State<_HoverMarker> createState() => _HoverMarkerState();
}

class _HoverMarkerState extends State<_HoverMarker> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _hovered ? 1.3 : 1.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
