import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/kakao_local_service.dart';
import '../services/location_search_result.dart';
import '../providers/map_provider.dart';
import '../data/map_repository.dart';

class MapSidebarView extends ConsumerStatefulWidget {
  const MapSidebarView({super.key});

  @override
  ConsumerState<MapSidebarView> createState() => _MapSidebarViewState();
}

class _MapSidebarViewState extends ConsumerState<MapSidebarView> {
  bool _isSearchTab = true;
  final _searchController = TextEditingController();
  List<LocationSearchResult> _results = [];
  bool _isLoading = false;

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
      _results = [];
    });
    try {
      final results = await KakaoLocalService().search(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _selectResult(LocationSearchResult result) {
    ref
        .read(selectedLocationProvider.notifier)
        .select(
          SelectedLocation(
            name: result.name,
            position: LatLng(result.lat, result.lng),
          ),
        );
  }

  void _showTagSaveDialog(LocationSearchResult result) async {
    final tags = await ref.read(mapTagProvider.future);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _TagSelectDialog(
        result: result,
        tags: tags,
        onSave: (tagId) async {
          await ref
              .read(mapPlaceProvider.notifier)
              .addPlace(
                MapPlace(
                  name: result.name,
                  address: result.address,
                  lat: result.lat,
                  lng: result.lng,
                  tagId: tagId,
                  createdAt: DateTime.now().toIso8601String(),
                ),
              );
        },
        onCreateTag: (name, color) async {
          await ref.read(mapTagProvider.notifier).createTag(name, color);
          final newTags = await ref.read(mapTagProvider.future);
          return newTags.last.id!;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 탭 토글
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSearchTab = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSearchTab
                          ? const Color(0xFF4A90E2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4A90E2)),
                    ),
                    child: Center(
                      child: Text(
                        '검색',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSearchTab
                              ? Colors.white
                              : const Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSearchTab = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isSearchTab
                          ? const Color(0xFF4A90E2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4A90E2)),
                    ),
                    child: Center(
                      child: Text(
                        '저장된 장소',
                        style: TextStyle(
                          fontSize: 12,
                          color: !_isSearchTab
                              ? Colors.white
                              : const Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_isSearchTab) _buildSearchTab(),
        if (!_isSearchTab) _buildSavedTab(),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.place,
                          size: 16,
                          color: Colors.grey,
                        ),
                        title: Text(
                          result.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          result.address,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.label,
                            size: 16,
                            color: Color(0xFF4A90E2),
                          ),
                          tooltip: '태그 저장',
                          onPressed: () => _showTagSaveDialog(result),
                        ),
                        onTap: () => _selectResult(result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    final tagsAsync = ref.watch(mapTagProvider);
    final activeTags = ref.watch(activeMapTagsProvider);
    final placesAsync = ref.watch(mapPlaceProvider);

    return Expanded(
      child: Column(
        children: [
          // 태그 목록
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '태그',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showCreateTagDialog(),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                tagsAsync.when(
                  loading: () => const SizedBox(),
                  error: (e, _) => const SizedBox(),
                  data: (tags) => tags.isEmpty
                      ? const Text(
                          '태그 없음',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        )
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags.map((tag) {
                            final isActive = activeTags.contains(tag.id);
                            final color = _hexToColor(tag.color);
                            return GestureDetector(
                              onTap: () => ref
                                  .read(activeMapTagsProvider.notifier)
                                  .toggle(tag.id!),
                              onLongPress: () => _showDeleteTagDialog(tag),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? color
                                      : color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color),
                                ),
                                child: Text(
                                  tag.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isActive ? Colors.white : color,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 장소 목록
          Expanded(
            child: placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
              data: (places) {
                final filtered = activeTags.isEmpty
                    ? places
                    : places
                          .where((p) => activeTags.contains(p.tagId))
                          .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      '저장된 장소 없음',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final place = filtered[index];
                    final tagsData = tagsAsync.value ?? [];
                    final tag = tagsData.firstWhere(
                      (t) => t.id == place.tagId,
                      orElse: () => MapTag(name: '', color: '#4A90E2'),
                    );
                    final color = _hexToColor(tag.color);

                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.place, size: 16, color: color),
                      title: Text(
                        place.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        place.address,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.grey,
                        ),
                        onPressed: () => ref
                            .read(mapPlaceProvider.notifier)
                            .deletePlace(place.id!),
                      ),
                      onTap: () {
                        ref
                            .read(selectedLocationProvider.notifier)
                            .select(
                              SelectedLocation(
                                name: place.name,
                                position: LatLng(place.lat, place.lng),
                              ),
                            );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTagDialog() {
    final nameController = TextEditingController();
    String selectedColor = '#4A90E2';
    final colors = [
      '#E53935',
      '#FF9800',
      '#4CAF50',
      '#4A90E2',
      '#9C27B0',
      '#FF5722',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('태그 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '태그 이름'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: colors.map((hex) {
                  final color = _hexToColor(hex);
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == hex
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref
                      .read(mapTagProvider.notifier)
                      .createTag(nameController.text, selectedColor);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTagDialog(MapTag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('태그 삭제'),
        content: Text('"${tag.name}" 태그와 저장된 장소가 모두 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(mapTagProvider.notifier).deleteTag(tag.id!);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4A90E2);
    }
  }
}

// 태그 선택 다이얼로그
class _TagSelectDialog extends StatefulWidget {
  final LocationSearchResult result;
  final List<MapTag> tags;
  final Future<void> Function(int tagId) onSave;
  final Future<int> Function(String name, String color) onCreateTag;

  const _TagSelectDialog({
    required this.result,
    required this.tags,
    required this.onSave,
    required this.onCreateTag,
  });

  @override
  State<_TagSelectDialog> createState() => _TagSelectDialogState();
}

class _TagSelectDialogState extends State<_TagSelectDialog> {
  int? _selectedTagId;
  List<MapTag> _tags = [];
  final _newTagController = TextEditingController();
  String _newTagColor = '#4A90E2';
  bool _isCreating = false;

  final _colors = [
    '#E53935',
    '#FF9800',
    '#4CAF50',
    '#4A90E2',
    '#9C27B0',
    '#FF5722',
  ];

  @override
  void initState() {
    super.initState();
    _tags = widget.tags;
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4A90E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('"${widget.result.name}" 저장'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '태그 선택',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((tag) {
                final isSelected = _selectedTagId == tag.id;
                final color = _hexToColor(tag.color);
                return GestureDetector(
                  onTap: () => setState(() => _selectedTagId = tag.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isCreating = !_isCreating),
              child: const Text(
                '+ 새 태그 만들기',
                style: TextStyle(fontSize: 12, color: Color(0xFF4A90E2)),
              ),
            ),
            if (_isCreating) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _newTagController,
                decoration: const InputDecoration(
                  hintText: '태그 이름',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _colors.map((hex) {
                  final color = _hexToColor(hex);
                  return GestureDetector(
                    onTap: () => setState(() => _newTagColor = hex),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _newTagColor == hex
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              TextButton(
                onPressed: () async {
                  if (_newTagController.text.isEmpty) return;
                  final newId = await widget.onCreateTag(
                    _newTagController.text,
                    _newTagColor,
                  );
                  setState(() {
                    _tags = [
                      ..._tags,
                      MapTag(
                        id: newId,
                        name: _newTagController.text,
                        color: _newTagColor,
                      ),
                    ];
                    _selectedTagId = newId;
                    _isCreating = false;
                  });
                },
                child: const Text('태그 생성'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _selectedTagId == null
              ? null
              : () async {
                  await widget.onSave(_selectedTagId!);
                  if (context.mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A90E2),
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
