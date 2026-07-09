import 'package:drift/drift.dart';

class Note {
  final int? id;
  final String title;
  final String content;
  final List<String> tags;
  final String createdAt;
  final String updatedAt;
  final int? folderId;
  final double? sortOrder;
  final String? deletedAt;
  final bool isPinned;
  final bool isImportant;
  final bool isFavorite;
  final double favoriteSortOrder;

  const Note({
    this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.sortOrder,
    this.deletedAt,
    this.isPinned = false,
    this.isImportant = false,
    this.isFavorite = false,
    this.favoriteSortOrder = 0.0,
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
    Value<String?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isImportant,
    bool? isFavorite,
    double? favoriteSortOrder,
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
      deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isImportant: isImportant ?? this.isImportant,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteSortOrder: favoriteSortOrder ?? this.favoriteSortOrder,
    );
  }
}
