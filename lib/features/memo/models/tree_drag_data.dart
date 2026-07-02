// 드래그 데이터 타입
class TreeDragData {
  final bool isFolder;
  final int id;
  final int? parentId;
  final double sortOrder;

  const TreeDragData({
    required this.isFolder,
    required this.id,
    this.parentId,
    required this.sortOrder,
  });
}
