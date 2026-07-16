import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_repository.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';

// 검색어 상태
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// 선택된 메모 상태
class SelectedNoteNotifier extends Notifier<Note?> {
  @override
  Note? build() => null;

  void select(Note? note) => state = note;
}

final selectedNoteProvider = NotifierProvider<SelectedNoteNotifier, Note?>(
  SelectedNoteNotifier.new,
);

// 메모 목록 상태
class NoteListNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    return _fetchNotes();
  }

  Future<void> moveNoteWithOrder(
    int noteId,
    int? folderId,
    double newSortOrder,
  ) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.moveNote(noteId, folderId);
    await repo.updateNoteSortOrder(noteId, newSortOrder);
    ref.invalidateSelf();
  }

  Future<void> moveNote(int noteId, int folderId) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.moveNote(noteId, folderId);
    ref.invalidateSelf();
  }

  Future<List<Note>> _fetchNotes() async {
    final query = ref.watch(searchQueryProvider);
    final repo = ref.watch(noteRepositoryProvider);
    if (query.isEmpty) {
      return repo.getAllNotes();
    }
    return repo.searchNotes(query);
  }

  Future<void> createNote() async {
    final repo = ref.read(noteRepositoryProvider);
    final selectedFolder = ref.read(selectedFolderProvider);

    final currentNotes = (state.value ?? [])
        .where((n) => n.folderId == selectedFolder?.id)
        .toList();
    final maxSortOrder = currentNotes.isEmpty
        ? 0.0
        : currentNotes
              .map((n) => n.sortOrder ?? 0.0)
              .reduce((a, b) => a > b ? a : b);

    final note = await repo.createNote(
      folderId: selectedFolder?.id,
      sortOrder: maxSortOrder + 1.0,
    );
    final current = state.value ?? [];
    state = AsyncData([note, ...current]);
    ref.read(selectedNoteProvider.notifier).select(note);
  }

  Future<void> saveNote(Note note) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.saveNote(note);
    final current = state.value ?? [];
    state = AsyncData(current.map((n) => n.id == note.id ? note : n).toList());
  }

  Future<void> deleteNote(int id) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.deleteNote(id);
    final current = state.value ?? [];
    state = AsyncData(current.where((n) => n.id != id).toList());
    // 삭제된 메모가 선택 중이면 선택 해제
    final selected = ref.read(selectedNoteProvider);
    if (selected?.id == id) {
      ref.read(selectedNoteProvider.notifier).select(null);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchNotes);
  }

  Future<void> togglePin(int id, bool isPinned) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.togglePin(id, isPinned);
    ref.invalidateSelf();
  }

  Future<void> toggleImportant(int id, bool isImportant) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.toggleImportant(id, isImportant);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final repo = ref.read(noteRepositoryProvider);
    final notes = state.value ?? [];
    final maxOrder = notes
        .where((n) => n.isFavorite)
        .fold(
          0.0,
          (max, n) => n.favoriteSortOrder > max ? n.favoriteSortOrder : max,
        );
    await repo.toggleFavorite(
      id,
      isFavorite,
      isFavorite ? maxOrder + 1.0 : 0.0,
    );
    ref.invalidateSelf();
  }

  Future<void> updateFavoriteSortOrder(int id, double sortOrder) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.updateFavoriteSortOrder(id, sortOrder);
    ref.invalidateSelf();
  }
}

final noteListProvider = AsyncNotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);

class TrashNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repo = ref.watch(noteRepositoryProvider);
    return repo.getDeletedNotes();
  }

  Future<void> loadMore() async {
    final repo = ref.read(noteRepositoryProvider);
    final current = state.value ?? [];
    final page = current.length ~/ 20;
    final more = await repo.getDeletedNotes(page: page);
    state = AsyncData([...current, ...more]);
  }

  Future<void> restore(int id) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.restoreNote(id);
    ref.invalidateSelf();
    ref.invalidate(noteListProvider);
  }

  Future<void> permanentlyDelete(int id) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.permanentlyDeleteNote(id);
    ref.invalidateSelf();
  }

  Future<void> emptyTrash() async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.emptyTrash();
    ref.invalidateSelf();
  }

  Future<void> togglePin(int id, bool isPinned) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.togglePin(id, isPinned);
    ref.invalidateSelf();
  }

  Future<void> toggleImportant(int id, bool isImportant) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.toggleImportant(id, isImportant);
    ref.invalidateSelf();
  }
}

final trashProvider = AsyncNotifierProvider<TrashNotifier, List<Note>>(
  TrashNotifier.new,
);
