import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/map_provider.dart';
import '../services/vworld_service.dart';
import '../model/search_type.dart';

class MapSidebarView extends ConsumerStatefulWidget {
  const MapSidebarView({super.key});

  @override
  ConsumerState<MapSidebarView> createState() => _MapSidebarViewState();
}

class _MapSidebarViewState extends ConsumerState<MapSidebarView> {
  final _searchController = TextEditingController();
  List<VworldSearchResult> _results = [];
  bool _isLoading = false;
  String? _error;
  SearchType _searchType = SearchType.place; // 기본값 장소

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final service = VworldService();
      final results = _searchType == SearchType.place
          ? await service.search(query)
          : await service.searchAddress(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '검색 실패: $e';
        _isLoading = false;
      });
    }
  }

  void _selectResult(VworldSearchResult result) {
    ref
        .read(selectedLocationProvider.notifier)
        .select(
          SelectedLocation(
            name: result.name,
            position: LatLng(result.lat, result.lng),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = ref.watch(selectedLocationProvider);

    return Column(
      children: [
        // 검색창
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '장소 검색',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: _search,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SegmentedButton<SearchType>(
            segments: const [
              ButtonSegment(
                value: SearchType.place,
                label: Text('장소', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.place, size: 14),
              ),
              ButtonSegment(
                value: SearchType.address,
                label: Text('주소', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.home, size: 14),
              ),
            ],
            selected: {_searchType},
            onSelectionChanged: (value) {
              setState(() {
                _searchType = value.first;
                _results = []; // 타입 바꾸면 결과 초기화
              });
            },
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
        const SizedBox(height: 8),

        // 선택된 위치
        if (selectedLocation != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_pin,
                  color: Color(0xFFE53935),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedLocation.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () =>
                      ref.read(selectedLocationProvider.notifier).select(null),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // 결과 목록
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : _results.isEmpty
              ? const Center(
                  child: Text(
                    '장소를 검색하세요',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    final isSelected = selectedLocation?.name == result.name;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.place,
                        size: 16,
                        color: isSelected
                            ? const Color(0xFF4A90E2)
                            : Colors.grey,
                      ),
                      title: Text(
                        result.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        result.address,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFE8F0FE),
                      onTap: () => _selectResult(result),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
