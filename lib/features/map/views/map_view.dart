import 'dart:math';
import 'package:taskmanager/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../calendar/providers/event_provider.dart';
import '../../calendar/views/calendar_editor_view.dart';
import '../../memo/providers/note_provider.dart';
import '../providers/map_event_provider.dart';
import '../providers/map_provider.dart';
import '../data/map_repository.dart';
import '../services/kakao_local_service.dart';
import '../services/location_search_result.dart';
import '../widgets/directions_button.dart';

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
  int _categorySeq = 0; // 늦게 온 이전 카테고리 응답 무시용

  // 메인 탭 순서 (main.dart의 _navigationDestinations)
  static const _calendarTab = 1;
  static const _eventColor = Color(0xFF7E57C2);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _toggleCategory(String code) async {
    final current = ref.read(activeCategoryProvider);
    final seq = ++_categorySeq;

    // 같은 카테고리 누르면 해제
    if (current == code) {
      ref.read(activeCategoryProvider.notifier).set(null);
      ref.read(nearbyRestaurantsProvider.notifier).clear();
      if (_isLoadingCategory) setState(() => _isLoadingCategory = false);
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
      if (!mounted || seq != _categorySeq) return;
      ref.read(nearbyRestaurantsProvider.notifier).setRestaurants(results);
      ref.read(activeCategoryProvider.notifier).set(code);
    } catch (e) {
      // 실패 무시
    } finally {
      if (mounted && seq == _categorySeq) {
        setState(() => _isLoadingCategory = false);
      }
    }
  }

  void _toggleEvents(List<EventPlace> places) {
    final willShow = !ref.read(showEventsOnMapProvider);
    ref.read(showEventsOnMapProvider.notifier).toggle();
    if (!willShow || places.isEmpty) return;
    if (places.length == 1) {
      _mapController.move(places.first.position, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: places.map((p) => p.position).toList(),
        padding: const EdgeInsets.all(64),
        maxZoom: 16,
      ),
    );
  }

  void _openEventDate(String date) {
    final d = DateTime.parse(date);
    ref.read(currentMonthProvider.notifier)
      ..setYear(d.year)
      ..setMonth(d.month);
    ref.read(selectedDateProvider.notifier).select(d);
    ref.read(navigationProvider.notifier).navigateTo(_calendarTab);
  }

  // ───────────── 장소 고르기 → 메모·일정

  static const _memoTab = 0;

  /// 지도 빈 곳을 누름: 그 자리를 고르고 주소를 찾아 채움
  Future<void> _pickPoint(LatLng position) async {
    final notifier = ref.read(selectedLocationProvider.notifier);
    notifier.select(
      SelectedLocation(name: '선택한 위치', position: position, fromMapTap: true),
    );
    // 지도 아이콘은 그림이라 직접 누를 수 없음 → 누른 곳 근처(화면에서 약 24px)의
    // 장소를 찾아 그곳을 누른 것으로 봄
    final camera = _mapController.camera;
    final metersPerPixel =
        156543.03 * cos(position.latitude * pi / 180) / pow(2, camera.zoom);
    final radius = (metersPerPixel * 24).round().clamp(15, 300);
    final service = KakaoLocalService();
    try {
      final (place, address) = await (
        service
            .nearestPlace(position.latitude, position.longitude, radius: radius)
            .catchError((Object _) => null),
        service
            .coordToAddress(position.latitude, position.longitude)
            .catchError((Object _) => null),
      ).wait;
      // 그사이 다른 곳을 골랐으면 버림
      if (!mounted ||
          ref.read(selectedLocationProvider)?.position != position) {
        return;
      }
      if (place != null) {
        // 그 장소 위치로 핀을 옮기고 지도를 맞춤.
        // 같은 건물 안의 장소면 건물 이름(예: 서울특별시청)이 더 알맞음
        final sameBuilding =
            address != null &&
            address.name != address.address &&
            _withoutProvince(address.address) ==
                _withoutProvince(place.address);
        final target = LatLng(place.lat, place.lng);
        notifier.select(
          SelectedLocation(
            name: sameBuilding ? address.name : place.name,
            address: place.address,
            position: target,
            fromMapTap: true,
          ),
        );
        _mapController.move(target, max(_mapController.camera.zoom, 17));
        return;
      }
      if (address == null) return;
      notifier.select(
        SelectedLocation(
          name: address.name,
          address: address.address,
          position: position,
          fromMapTap: true,
        ),
      );
    } catch (_) {
      // 주소를 못 찾아도 좌표로 계속 쓸 수 있음
    }
  }

  /// "서울특별시 중구 …"와 "서울 중구 …"를 같게 보려고 첫 단어(시·도)를 뺌
  static String _withoutProvince(String address) =>
      address.trim().split(RegExp(r'\s+')).skip(1).join(' ');

  /// 메모에 추가: 지금 메모 또는 새 메모 (메모 탭으로 가서 끝에 위치 블록을 넣음)
  Future<void> _addToMemo(SelectedLocation place, Offset position) async {
    final current = ref.read(selectedNoteProvider);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(position) & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (current?.id != null)
          PopupMenuItem(
            value: 'current',
            height: 36,
            child: Text(
              '"${current!.title.trim().isEmpty ? '제목 없음' : current.title}" 메모에 추가',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        const PopupMenuItem(
          value: 'new',
          height: 36,
          child: Text('새 메모로 만들기', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
    if (!mounted || choice == null) return;
    final int noteId;
    if (choice == 'new') {
      await ref.read(noteListProvider.notifier).createNote();
      final created = ref.read(selectedNoteProvider);
      if (!mounted || created?.id == null) return;
      noteId = created!.id!;
    } else {
      noteId = current!.id!;
    }
    ref.read(memoLocationRequestProvider.notifier).request((
      noteId: noteId,
      name: place.name,
      address: place.address,
      lat: place.position.latitude,
      lng: place.position.longitude,
    ));
    ref.read(navigationProvider.notifier).navigateTo(_memoTab);
  }

  Future<void> _addToCalendar(SelectedLocation place) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await showDialog(
      context: context,
      builder: (context) => EventDialog(
        initialDate: today,
        initialTitle: place.name,
        initialLocationName: place.name,
        initialLat: place.position.latitude,
        initialLng: place.position.longitude,
      ),
    );
  }

  String _eventTooltip(EventPlace place) {
    final lines = <String>[if (place.name != null) place.name!];
    for (final e in place.events.take(5)) {
      final d = DateTime.parse(e.eventDate);
      final time = e.isAllDay ? '' : ' ${e.startTime ?? ''}';
      lines.add('${d.month}/${d.day}$time  ${e.title}');
    }
    if (place.events.length > 5) {
      lines.add('외 ${place.events.length - 5}개');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final activeTags = ref.watch(activeMapTagsProvider);
    final showEvents = ref.watch(showEventsOnMapProvider);
    final eventPlaces = ref.watch(mapEventPlacesProvider).value ?? [];
    final placesAsync = ref.watch(mapPlaceProvider);
    final tagsAsync = ref.watch(mapTagProvider);
    final selectedLocation = ref.watch(selectedLocationProvider);
    final categoryResults = ref.watch(nearbyRestaurantsProvider);
    final activeCategory = ref.watch(activeCategoryProvider);
    final searchResults = ref.watch(searchResultsProvider);

    ref.listen(selectedLocationProvider, (prev, next) {
      // 지도를 직접 누른 곳이나 주소만 채워진 경우는 지도를 옮기지 않음
      if (next != null && !next.fromMapTap && next.position != prev?.position) {
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
            initialCenter:
                ref.read(selectedLocationProvider)?.position ?? _defaultCenter,
            initialZoom: ref.read(selectedLocationProvider) != null
                ? 16
                : _defaultZoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            // 빈 곳을 누르면 그 자리를 골라 메모·일정에 넣을 수 있게
            onTap: (_, point) => _pickPoint(point),
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

            // 일정 장소 마커 (앞으로 30일)
            if (showEvents && eventPlaces.isNotEmpty)
              MarkerLayer(
                markers: eventPlaces.map((place) {
                  return Marker(
                    point: place.position,
                    width: 30,
                    height: 30,
                    child: _HoverMarker(
                      tooltip: _eventTooltip(place),
                      size: 30,
                      onTap: () => _openEventDate(place.events.first.eventDate),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.event_available,
                            color: _eventColor,
                            size: 26,
                          ),
                          if (place.events.length > 1)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: _eventColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${place.events.length}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
                                address: place.address,
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
                                  address: place.address,
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
                                address: r.address,
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
                                  address: r.address,
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
                                address: r.address,
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
                                  address: r.address,
                                  position: LatLng(r.lat, r.lng),
                                ),
                              );
                          _mapController.move(LatLng(r.lat, r.lng), _maxZoom);
                        },
                        child: Icon(
                          Icons.place,
                          color: context.accent,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // 지도를 눌러 고른 곳 (다른 마커가 없는 자리라 핀을 꽂음)
            if (selectedLocation != null && selectedLocation.fromMapTap)
              MarkerLayer(
                markers: [
                  Marker(
                    point: selectedLocation.position,
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter, // 핀 끝이 그 자리에
                    child: const Icon(
                      Icons.location_pin,
                      color: Color(0xFFE53935),
                      size: 36,
                    ),
                  ),
                ],
              ),
          ],
        ),

        // 고른 장소 카드: 메모에 추가 / 일정 만들기
        if (selectedLocation != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Center(
              child: _PlaceCard(
                place: selectedLocation,
                onAddToMemo: (position) =>
                    _addToMemo(selectedLocation, position),
                onAddToCalendar: () => _addToCalendar(selectedLocation),
                onClose: () =>
                    ref.read(selectedLocationProvider.notifier).select(null),
              ),
            ),
          ),

        // 좌상단 카테고리 버튼들
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _MapChip(
                    icon: Icons.event_available,
                    label:
                        '일정 ${eventPlaces.fold<int>(0, (n, p) => n + p.events.length)}',
                    color: _eventColor,
                    isActive: showEvents,
                    tooltip: '앞으로 $mapEventDays일 동안 장소가 있는 일정',
                    onTap: () => _toggleEvents(eventPlaces),
                  ),
                ),
                ..._categories.map((cat) {
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _MapChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
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
              Icon(icon, size: 13, color: isActive ? Colors.white : color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
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

/// 지도에서 고른 장소 정보와 메모·캘린더 연동 버튼
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onAddToMemo,
    required this.onAddToCalendar,
    required this.onClose,
  });

  final SelectedLocation place;

  /// 누른 버튼 위치 (메뉴를 그 자리에 띄움)
  final void Function(Offset position) onAddToMemo;
  final VoidCallback onAddToCalendar;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = place.position;
    final subtitle = place.address.isNotEmpty && place.address != place.name
        ? place.address
        : '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Material(
        color: context.popupSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place, size: 20, color: context.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '닫기',
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Builder(
                    builder: (buttonContext) => TextButton.icon(
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: const Text('메모에 추가'),
                      onPressed: () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        onAddToMemo(
                          box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('일정 만들기'),
                    onPressed: onAddToCalendar,
                  ),
                  const SizedBox(width: 4),
                  DirectionsButton(
                    name: place.name,
                    lat: p.latitude,
                    lng: p.longitude,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
