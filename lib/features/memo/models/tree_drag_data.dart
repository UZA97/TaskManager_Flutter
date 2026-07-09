class TreeDragData {
  final bool isFolder;
  final int id;
  final int? parentId;
  final double sortOrder;
  final bool isFavoriteItem; // 추가

  const TreeDragData({
    required this.isFolder,
    required this.id,
    this.parentId,
    required this.sortOrder,
    this.isFavoriteItem = false,
  });
}
