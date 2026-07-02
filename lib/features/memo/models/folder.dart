class Folder {
  final int? id;
  final String name;
  final int? parentId;
  final double sortOrder;
  final String createdAt;

  const Folder({
    this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0.0,
    required this.createdAt,
  });

  Folder copyWith({
    int? id,
    String? name,
    int? parentId,
    double? sortOrder,
    String? createdAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
