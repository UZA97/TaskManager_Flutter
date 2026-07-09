import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/folder.dart';

class FolderRepository {
  final AppDatabase _db;

  FolderRepository(this._db);

  // 전체 폴더 로드
  Future<List<Folder>> getAllFolders() async {
    final rows =
        await (_db.select(_db.folderTable)..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
            .get();
    return rows.map(_rowToFolder).toList();
  }

  Future<Folder> createFolder({required String name, int? parentId}) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db
        .into(_db.folderTable)
        .insert(
          FolderTableCompanion.insert(
            name: name,
            parentId: Value(parentId),
            createdAt: now,
          ),
        );
    return Folder(id: id, name: name, parentId: parentId, createdAt: now);
  }

  Future<void> renameFolder(int id, String name) async {
    await (_db.update(_db.folderTable)..where((t) => t.id.equals(id))).write(
      FolderTableCompanion(name: Value(name)),
    );
  }

  Future<void> moveFolder(int id, int? newParentId) async {
    await (_db.update(_db.folderTable)..where((t) => t.id.equals(id))).write(
      FolderTableCompanion(parentId: Value(newParentId)),
    );
  }

  // 폴더 삭제 — 하위 폴더/메모 cascade는 호출부에서 처리
  Future<void> deleteFolder(int id) async {
    await (_db.delete(_db.folderTable)..where((t) => t.id.equals(id))).go();
  }

  // 하위 폴더 id 전체 수집 (재귀)
  List<int> collectDescendantIds(List<Folder> allFolders, int rootId) {
    final result = <int>[];
    final queue = <int>[rootId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      result.add(current);
      final children = allFolders
          .where((f) => f.parentId == current)
          .map((f) => f.id!)
          .toList();
      queue.addAll(children);
    }
    return result;
  }

  Future<void> updateSortOrder(int id, double sortOrder) async {
    await (_db.update(_db.folderTable)..where((t) => t.id.equals(id))).write(
      FolderTableCompanion(sortOrder: Value(sortOrder)),
    );
  }

  Future<void> togglePin(int id, bool isPinned) async {
    await (_db.update(_db.folderTable)..where((t) => t.id.equals(id))).write(
      FolderTableCompanion(isPinned: Value(isPinned)),
    );
  }

  Folder _rowToFolder(FolderTableData row) {
    return Folder(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      isPinned: row.isPinned,
      isFavorite: row.isFavorite,
      favoriteSortOrder: row.favoriteSortOrder,
    );
  }

  Future<void> toggleFavorite(int id, bool isFavorite, double sortOrder) async {
    await (_db.update(_db.folderTable)..where((t) => t.id.equals(id))).write(
      FolderTableCompanion(
        isFavorite: Value(isFavorite),
        favoriteSortOrder: Value(sortOrder),
      ),
    );
  }

  Future<void> updateFavoriteSortOrder(int id, double sortOrder) async {
    await (_db.update(_db.folderTable)..where((t) => t.id.equals(id))).write(
      FolderTableCompanion(favoriteSortOrder: Value(sortOrder)),
    );
  }
}

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FolderRepository(db);
});
