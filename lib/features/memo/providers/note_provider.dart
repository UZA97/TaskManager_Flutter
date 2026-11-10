import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_repository.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';
import 'tab_provider.dart';

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

// 메모를 연 뒤 커서를 옮길 체크리스트 항목 (오늘 브리핑에서 이동할 때)
typedef MemoFocusRequest = ({int noteId, List<int> path, String text});

class MemoFocusRequestNotifier extends Notifier<MemoFocusRequest?> {
  @override
  MemoFocusRequest? build() => null;

  void request(MemoFocusRequest? value) => state = value;
}

final memoFocusRequestProvider =
    NotifierProvider<MemoFocusRequestNotifier, MemoFocusRequest?>(
      MemoFocusRequestNotifier.new,
    );

/// 지도에서 고른 장소를 메모에 넣어 달라는 요청 (메모 에디터가 열리면 처리)
typedef MemoLocationRequest = ({
  int noteId,
  String name,
  String address,
  double lat,
  double lng,
});

class MemoLocationRequestNotifier extends Notifier<MemoLocationRequest?> {
  @override
  MemoLocationRequest? build() => null;

  void request(MemoLocationRequest? value) => state = value;
}

final memoLocationRequestProvider =
    NotifierProvider<MemoLocationRequestNotifier, MemoLocationRequest?>(
      MemoLocationRequestNotifier.new,
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

  Future<void> createNote({int? folderId}) async {
    final repo = ref.read(noteRepositoryProvider);
    // folderId 파라미터가 명시적으로 넘어오면 그것 사용
    // 없으면 현재 선택된 폴더 사용
    final targetFolderId = folderId ?? ref.read(selectedFolderProvider)?.id;

    final currentNotes = (state.value ?? [])
        .where((n) => n.folderId == targetFolderId)
        .toList();
    final maxSortOrder = currentNotes.isEmpty
        ? 0.0
        : currentNotes
              .map((n) => n.sortOrder ?? 0.0)
              .reduce((a, b) => a > b ? a : b);

    final note = await repo.createNote(
      folderId: targetFolderId,
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
    // 탭에서도 제거
    ref.read(tabProvider.notifier).closeTab(id);
    // 휴지통 목록 갱신
    ref.invalidate(trashProvider);
  }

  // 기존 목록은 유지한 채 다시 읽음 (트리가 사라지거나 펼친 폴더가 접히지 않도록)
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // 오류는 state(AsyncError)로 화면에 표시됨
    }
  }

  /// 검색 필터와 무관하게 id로 메모 찾기 (휴지통·없는 메모는 null)
  Future<Note?> findById(int id) async {
    for (final note in state.value ?? const <Note>[]) {
      if (note.id == id) return note;
    }
    return ref.read(noteRepositoryProvider).getNoteById(id);
  }

  /// id로 찾아 선택 (못 찾으면 선택 해제)
  Future<void> selectById(int? id) async {
    final note = id == null ? null : await findById(id);
    ref.read(selectedNoteProvider.notifier).select(note);
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

/// 탭에 열린 메모 (검색으로 목록에서 빠진 메모는 DB에서 id로 조회)
final tabNotesProvider = FutureProvider<Map<int, Note>>((ref) async {
  final ids = ref.watch(
    tabProvider.select((s) => s.value?.tabNoteIds ?? const <int>[]),
  );
  final listed = ref.watch(noteListProvider).value ?? const <Note>[];
  final idSet = ids.toSet();
  final result = <int, Note>{
    for (final n in listed)
      if (idSet.contains(n.id)) n.id!: n,
  };
  final missing = idSet.where((id) => !result.containsKey(id));
  if (missing.isNotEmpty) {
    final repo = ref.read(noteRepositoryProvider);
    for (final n in await repo.getNotesByIds(missing)) {
      result[n.id!] = n;
    }
  }
  return result;
});

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
