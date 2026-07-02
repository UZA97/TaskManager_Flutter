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

    // 선택된 폴더 없으면 생성 불가
    if (selectedFolder == null) return;

    final note = await repo.createNote(folderId: selectedFolder.id);
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
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchNotes);
  }
}

final noteListProvider = AsyncNotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);
