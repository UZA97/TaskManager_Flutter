import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/folder_repository.dart';
import '../data/note_repository.dart';
import '../models/folder.dart';
import '../models/note.dart';
import 'note_provider.dart';

// 전체 폴더 상태
class FolderListNotifier extends AsyncNotifier<List<Folder>> {
  @override
  Future<List<Folder>> build() async {
    final repo = ref.watch(folderRepositoryProvider);
    return repo.getAllFolders();
  }

  Future<void> moveFolderWithOrder(
    int id,
    int? newParentId,
    double newSortOrder,
  ) async {
    final allFolders = state.value ?? [];
    final repo = ref.read(folderRepositoryProvider);

    // 순환 참조 방지
    final descendants = repo.collectDescendantIds(allFolders, id);
    if (newParentId != null && descendants.contains(newParentId)) return;

    await repo.moveFolder(id, newParentId);
    await repo.updateSortOrder(id, newSortOrder);
    ref.invalidateSelf();
  }

  Future<void> createFolder({required String name, int? parentId}) async {
    final repo = ref.read(folderRepositoryProvider);
    await repo.createFolder(name: name, parentId: parentId);
    ref.invalidateSelf();
  }

  Future<void> renameFolder(int id, String name) async {
    final repo = ref.read(folderRepositoryProvider);
    await repo.renameFolder(id, name);
    ref.invalidateSelf();
  }

  Future<void> deleteFolder(int id) async {
    final repo = ref.read(folderRepositoryProvider);
    final allFolders = state.value ?? [];

    // 하위 폴더 id 전부 수집
    final folderIds = repo.collectDescendantIds(allFolders, id);

    // 각 폴더의 메모 삭제
    final noteRepo = ref.read(noteRepositoryProvider);
    for (final folderId in folderIds) {
      await noteRepo.deleteNotesByFolder(folderId);
    }

    // 폴더 삭제 (하위부터 역순으로)
    for (final folderId in folderIds.reversed) {
      await repo.deleteFolder(folderId);
    }

    ref.invalidateSelf();
    ref.invalidate(noteListProvider);
  }

  Future<void> moveFolder(int id, int? newParentId) async {
    // 순환 참조 방지 — 자기 자신이나 자손으로 이동 불가
    final allFolders = state.value ?? [];
    final repo = ref.read(folderRepositoryProvider);
    final descendantIds = repo.collectDescendantIds(allFolders, id);
    if (newParentId != null && descendantIds.contains(newParentId)) return;

    await repo.moveFolder(id, newParentId);
    ref.invalidateSelf();
  }
}

final folderListProvider =
    AsyncNotifierProvider<FolderListNotifier, List<Folder>>(
      FolderListNotifier.new,
    );

// 선택된 폴더
class SelectedFolderNotifier extends Notifier<Folder?> {
  @override
  Folder? build() => null;

  void select(Folder? folder) {
    // 같은 폴더 클릭 시 선택 해제
    if (state?.id == folder?.id) {
      state = null;
    } else {
      state = folder;
    }
  }
}

final selectedFolderProvider =
    NotifierProvider<SelectedFolderNotifier, Folder?>(
      SelectedFolderNotifier.new,
    );

// 선택된 폴더의 메모만 필터
final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(noteListProvider).value ?? [];
  final selectedFolder = ref.watch(selectedFolderProvider);
  // null이면 루트 메모 (folderId == null)
  return notes.where((n) => n.folderId == selectedFolder?.id).toList();
});
