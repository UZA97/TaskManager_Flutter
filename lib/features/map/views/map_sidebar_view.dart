import 'package:taskmanager/core/theme/app_colors.dart';
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
  int _searchSeq = 0; // 늦게 온 이전 검색 응답 무시용

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final seq = ++_searchSeq;
    setState(() {
      _isLoading = true;
      _results = [];
    });
    try {
      final results = await KakaoLocalService().search(query);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
      // 검색 결과 지도 마커 업데이트
      ref.read(searchResultsProvider.notifier).setResults(results);
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
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
    final scheme = Theme.of(context).colorScheme;

    // 탭 하나 (선택되면 옅은 테마색 바탕)
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
      child: Material(
        color: selected ? context.selectedTint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? context.accent : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      children: [
        // 상단: 제목
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '지도',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // 탭 토글 (묶음 컨테이너)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                tab('검색', _isSearchTab, () {
                  setState(() => _isSearchTab = true);
                }),
                const SizedBox(width: 3),
                tab('저장된 장소', !_isSearchTab, () {
                  setState(() => _isSearchTab = false);
                }),
              ],
            ),
          ),
        ),

        if (_isSearchTab) _buildSearchTab(),
        if (!_isSearchTab) _buildSavedTab(),
      ],
    );
  }

  Widget _buildSearchTab() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '장소 검색',
                prefixIcon: const Icon(Icons.search, size: 17),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  tooltip: '검색',
                  onPressed: _search,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                isDense: true,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Text(
                      '장소를 검색하세요',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _PlaceRow(
                        name: result.name,
                        address: result.address,
                        iconColor: muted,
                        onTap: () => _selectResult(result),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.label_outline,
                            size: 16,
                            color: context.accent,
                          ),
                          tooltip: '태그 저장',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          onPressed: () => _showTagSaveDialog(result),
                        ),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Expanded(
      child: Column(
        children: [
          // 태그 목록
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('태그', style: TextStyle(fontSize: 11, color: muted)),
                    const Spacer(),
                    Tooltip(
                      message: '태그 추가',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _showCreateTagDialog(),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.add, size: 16, color: muted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                tagsAsync.when(
                  loading: () => const SizedBox(),
                  error: (e, _) => const SizedBox(),
                  data: (tags) => tags.isEmpty
                      ? Text(
                          '태그 없음',
                          style: TextStyle(fontSize: 11, color: muted),
                        )
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags.map((tag) {
                            final isActive = activeTags.contains(tag.id);
                            final color = _hexToColor(tag.color);
                            return InputChip(
                              label: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive ? Colors.white : color,
                                ),
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: isActive
                                  ? color
                                  : color.withValues(alpha: 0.12),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onPressed: () => ref
                                  .read(activeMapTagsProvider.notifier)
                                  .toggle(tag.id!),
                              onDeleted: () => _showDeleteTagDialog(tag),
                              deleteIcon: Icon(
                                Icons.close,
                                size: 14,
                                color: isActive ? Colors.white : color,
                              ),
                              deleteButtonTooltipMessage: '삭제',
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.lineSubtle),
          // 장소 목록
          Expanded(
            child: placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
              data: (places) {
                final filtered = activeTags.isEmpty
                    ? <MapPlace>[]
                    : places
                          .where((p) => activeTags.contains(p.tagId))
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      '저장된 장소 없음',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final place = filtered[index];
                    final tagsData = tagsAsync.value ?? [];
                    final tag = tagsData.firstWhere(
                      (t) => t.id == place.tagId,
                      orElse: () => MapTag(name: '', color: '#4A90E2'),
                    );
                    final color = _hexToColor(tag.color);

                    return _PlaceRow(
                      name: place.name,
                      address: place.address,
                      iconColor: color,
                      trailing: IconButton(
                        icon: Icon(Icons.close, size: 14, color: muted),
                        tooltip: '삭제',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
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
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 2,
                              )
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
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('"${widget.result.name}" 저장'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '태그 선택',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
                      color: isSelected ? color : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : color,
                        fontWeight: isSelected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isCreating = !_isCreating),
              child: Text(
                '+ 새 태그 만들기',
                style: TextStyle(fontSize: 12, color: context.accent),
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
                            ? Border.all(color: scheme.onSurface, width: 2)
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
        FilledButton(
          onPressed: _selectedTagId == null
              ? null
              : () async {
                  await widget.onSave(_selectedTagId!);
                  if (context.mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
            backgroundColor: context.accent,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 장소 한 줄 (둥근 모서리, 메모 목록과 같은 간격)
class _PlaceRow extends StatelessWidget {
  final String name;
  final String address;
  final Color iconColor;
  final Widget trailing;
  final VoidCallback onTap;
  const _PlaceRow({
    required this.name,
    required this.address,
    required this.iconColor,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
            child: Row(
              children: [
                Icon(Icons.place, size: 16, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (address.isNotEmpty)
                        Text(
                          address,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
