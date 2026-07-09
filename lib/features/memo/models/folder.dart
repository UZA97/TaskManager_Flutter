class Folder {
  final int? id;
  final String name;
  final int? parentId;
  final double sortOrder;
  final String createdAt;
  final bool isPinned;
  final bool isFavorite;
  final double favoriteSortOrder;

  const Folder({
    this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0.0,
    required this.createdAt,
    this.isPinned = false,
    this.isFavorite = false,
    this.favoriteSortOrder = 0.0,
  });

  Folder copyWith({
    int? id,
    String? name,
    int? parentId,
    double? sortOrder,
    String? createdAt,
    bool? isPinned,
    bool? isFavorite,
    double? favoriteSortOrder,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteSortOrder: favoriteSortOrder ?? this.favoriteSortOrder,
    );
  }
}
