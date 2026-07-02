class Note {
  final int? id;
  final String title;
  final String content;
  final List<String> tags;
  final String createdAt;
  final String updatedAt;
  final int? folderId;
  final double? sortOrder;

  const Note({
    this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.sortOrder,
  });

  Note copyWith({
    int? id,
    String? title,
    String? content,
    List<String>? tags,
    String? createdAt,
    String? updatedAt,
    int? folderId,
    double? sortOrder,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
