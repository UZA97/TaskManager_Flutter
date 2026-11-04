import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/note.dart';

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);
  Note _rowToNote(NoteTableData row, List<String> tags) {
    return Note(
      id: row.id,
      title: row.title,
      content: row.content,
      tags: tags,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      folderId: row.folderId,
      sortOrder: row.sortOrder,
      deletedAt: row.deletedAt,
      isPinned: row.isPinned,
      isImportant: row.isImportant,
      isFavorite: row.isFavorite,
      favoriteSortOrder: row.favoriteSortOrder,
    );
  }

  Future<void> toggleFavorite(int id, bool isFavorite, double sortOrder) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(
        isFavorite: Value(isFavorite),
        favoriteSortOrder: Value(sortOrder),
      ),
    );
  }

  Future<void> updateFavoriteSortOrder(int id, double sortOrder) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(favoriteSortOrder: Value(sortOrder)),
    );
  }

  Future<void> togglePin(int id, bool isPinned) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(isPinned: Value(isPinned)),
    );
  }

  Future<void> toggleImportant(int id, bool isImportant) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(isImportant: Value(isImportant)),
    );
  }

  Future<List<Note>> getAllNotes() async {
    final rows = await (_db.select(
      _db.noteTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return _withTags(rows);
  }

  /// id로 메모 조회 (검색 필터와 무관, 휴지통 메모 제외)
  Future<Note?> getNoteById(int id) async {
    final row = await (_db.select(
      _db.noteTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return (await _withTags([row])).first;
  }

  Future<List<Note>> getNotesByIds(Iterable<int> ids) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return const [];
    final rows = await (_db.select(
      _db.noteTable,
    )..where((t) => t.id.isIn(idList) & t.deletedAt.isNull())).get();
    return _withTags(rows);
  }

  /// 태그를 한 번의 쿼리로 읽어 메모에 붙임 (N+1 방지)
  Future<List<Note>> _withTags(List<NoteTableData> rows) async {
    if (rows.isEmpty) return const [];
    final tagsByNote = await _tagsByNote(rows.map((r) => r.id).toList());
    return [
      for (final row in rows) _rowToNote(row, tagsByNote[row.id] ?? const []),
    ];
  }

  Future<Map<int, List<String>>> _tagsByNote(List<int> noteIds) async {
    final query = _db.select(_db.noteTagTable).join([
      innerJoin(
        _db.tagTable,
        _db.tagTable.id.equalsExp(_db.noteTagTable.tagId),
      ),
    ]);
    // 메모가 많으면 IN 목록 대신 전체를 읽어 거름 (sqlite 변수 개수 제한)
    if (noteIds.length <= 500) {
      query.where(_db.noteTagTable.noteId.isIn(noteIds));
    }
    final wanted = noteIds.toSet();
    final result = <int, List<String>>{};
    for (final r in await query.get()) {
      final noteId = r.readTable(_db.noteTagTable).noteId;
      if (!wanted.contains(noteId)) continue;
      (result[noteId] ??= []).add(r.readTable(_db.tagTable).name);
    }
    return result;
  }

  Future<List<Note>> searchNotes(String keyword) async {
    // 태그로 검색
    final tagQuery = _db.select(_db.noteTagTable).join([
      innerJoin(
        _db.tagTable,
        _db.tagTable.id.equalsExp(_db.noteTagTable.tagId),
      ),
    ])..where(_db.tagTable.name.contains(keyword));
    final tagRows = await tagQuery.get();
    final tagNoteIds = tagRows
        .map((r) => r.readTable(_db.noteTagTable).noteId)
        .toSet();

    // 제목/내용/태그로 1차 검색 (내용은 문서 JSON이라 아래에서 본문 글자로 다시 거름)
    final rows =
        await (_db.select(_db.noteTable)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    (t.title.contains(keyword) |
                        t.content.contains(keyword) |
                        t.id.isIn(tagNoteIds)),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    final notes = await _withTags(rows);
    return notes.where((n) => noteMatchesQuery(n, keyword)).toList();
  }

  /// [createdAt]: 가져온 메모처럼 원래 만든 시각을 지킬 때
  Future<Note> createNote({
    int? folderId,
    double sortOrder = 0.0,
    String? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now().toIso8601String();
    final id = await _db
        .into(_db.noteTable)
        .insert(
          NoteTableCompanion.insert(
            title: const Value(''),
            content: const Value(''),
            folderId: Value(folderId),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Note(
      id: id,
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      sortOrder: sortOrder,
    );
  }

  Future<void> saveNote(Note note) async {
    await (_db.update(
      _db.noteTable,
    )..where((t) => t.id.equals(note.id!))).write(
      NoteTableCompanion(
        title: Value(note.title),
        content: Value(note.content),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // 소프트 삭제
  Future<void> deleteNote(int id) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(deletedAt: Value(DateTime.now().toIso8601String())),
    );
  }

  // 휴지통 목록 (페이지네이션)
  Future<List<Note>> getDeletedNotes({int page = 0, int pageSize = 20}) async {
    final rows =
        await (_db.select(_db.noteTable)
              ..where((t) => t.deletedAt.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)])
              ..limit(pageSize, offset: page * pageSize))
            .get();
    return _withTags(rows);
  }

  // 복원 (원래 폴더가 삭제됐으면 루트로)
  Future<void> restoreNote(int id) async {
    final row = await (_db.select(
      _db.noteTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final folderId = row.folderId;
    var folderExists = true;
    if (folderId != null) {
      final folder = await (_db.select(
        _db.folderTable,
      )..where((t) => t.id.equals(folderId))).getSingleOrNull();
      folderExists = folder != null;
    }
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(
        deletedAt: const Value(null),
        folderId: folderExists ? const Value.absent() : const Value(null),
      ),
    );
  }

  // 영구 삭제
  Future<void> permanentlyDeleteNote(int id) async {
    await _purgeNotes([id]);
  }

  // 전체 비우기
  Future<void> emptyTrash() async {
    final rows = await (_db.select(
      _db.noteTable,
    )..where((t) => t.deletedAt.isNotNull())).get();
    await _purgeNotes(rows.map((r) => r.id).toList());
  }

  // 휴지통에서 [days]일 지난 메모 자동 삭제 (0이면 안 함)
  Future<void> deleteExpiredNotes({int days = 30}) async {
    if (days <= 0) return;
    final expiry = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    final rows =
        await (_db.select(_db.noteTable)..where(
              (t) =>
                  t.deletedAt.isNotNull() &
                  t.deletedAt.isSmallerThanValue(expiry),
            ))
            .get();
    await _purgeNotes(rows.map((r) => r.id).toList());
  }

  /// 메모 행 + 태그·첨부 행 + 첨부/버전 폴더까지 영구 삭제
  Future<void> _purgeNotes(List<int> ids) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      await _db.transaction(() async {
        await (_db.delete(
          _db.noteTagTable,
        )..where((t) => t.noteId.isIn(chunk))).go();
        await (_db.delete(
          _db.attachmentTable,
        )..where((t) => t.noteId.isIn(chunk))).go();
        await (_db.delete(_db.noteTable)..where((t) => t.id.isIn(chunk))).go();
      });
    }
    try {
      await _deleteNoteFolders(ids);
    } catch (e) {
      debugPrint('메모 첨부/버전 폴더 삭제 실패: $e');
    }
  }

  Future<void> _deleteNoteFolders(List<int> ids) async {
    final base = await getApplicationSupportDirectory();
    // 복제한 메모가 원본의 첨부 경로를 그대로 쓰므로, 남은 메모가 참조하면 유지
    final referencing = await (_db.select(
      _db.noteTable,
    )..where((t) => t.content.like('%Attachments%'))).get();
    final contents = [
      for (final r in referencing)
        r.content.replaceAll(r'\', '/').replaceAll('//', '/'),
    ];
    for (final id in ids) {
      final attachDir = Directory(p.join(base.path, 'Attachments', '$id'));
      final inUse = contents.any((c) => c.contains('Attachments/$id/'));
      if (!inUse && await attachDir.exists()) {
        await attachDir.delete(recursive: true);
      }
      // NoteVersionService와 같은 경로 (NoteVersions/<메모 id>)
      final versionDir = Directory(p.join(base.path, 'NoteVersions', '$id'));
      if (await versionDir.exists()) await versionDir.delete(recursive: true);
    }
  }

  Future<List<String>> getNoteTags(int noteId) async {
    final query = _db.select(_db.noteTagTable).join([
      innerJoin(
        _db.tagTable,
        _db.tagTable.id.equalsExp(_db.noteTagTable.tagId),
      ),
    ])..where(_db.noteTagTable.noteId.equals(noteId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.tagTable).name).toList();
  }

  Future<void> saveNoteTags(int noteId, List<String> tags) async {
    await (_db.delete(
      _db.noteTagTable,
    )..where((t) => t.noteId.equals(noteId))).go();

    for (final tag in tags) {
      // 태그 이미 있는지 확인
      var tagRow = await (_db.select(
        _db.tagTable,
      )..where((t) => t.name.equals(tag))).getSingleOrNull();

      // 없으면 새로 삽입
      if (tagRow == null) {
        final id = await _db
            .into(_db.tagTable)
            .insert(TagTableCompanion.insert(name: tag));
        tagRow = await (_db.select(
          _db.tagTable,
        )..where((t) => t.id.equals(id))).getSingle();
      }

      await _db
          .into(_db.noteTagTable)
          .insertOnConflictUpdate(
            NoteTagTableCompanion.insert(noteId: noteId, tagId: tagRow.id),
          );
    }
  }

  /// 폴더 안 메모를 휴지통으로 (소프트 삭제). 휴지통으로 간 메모 id 반환
  Future<List<int>> deleteNotesByFolder(int folderId) async {
    final rows = await (_db.select(
      _db.noteTable,
    )..where((t) => t.folderId.equals(folderId) & t.deletedAt.isNull())).get();
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    await (_db.update(_db.noteTable)..where((t) => t.id.isIn(ids))).write(
      NoteTableCompanion(deletedAt: Value(DateTime.now().toIso8601String())),
    );
    return ids;
  }

  Future<void> moveNote(int noteId, int? newFolderId) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(noteId))).write(
      NoteTableCompanion(folderId: Value(newFolderId)),
    ); // Value(null) 허용
  }

  Future<void> updateSortOrders(Map<int, double> sortOrders) async {
    for (final entry in sortOrders.entries) {
      await (_db.update(_db.folderTable)..where((t) => t.id.equals(entry.key)))
          .write(FolderTableCompanion(sortOrder: Value(entry.value)));
    }
  }

  Future<void> updateNoteSortOrder(int noteId, double sortOrder) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(noteId))).write(
      NoteTableCompanion(sortOrder: Value(sortOrder)),
    );
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return NoteRepository(db);
});

// ── 검색용 본문 글자 ─────────────────────────────────────────
// 메모 내용은 문서 JSON이라 원문으로 찾으면 "data", "insert" 같은 키까지 걸림

final _plainTextCache = <int, (String, String)>{};

/// 메모 본문의 글자만 (내용이 그대로면 캐시 사용)
String notePlainText(Note note) {
  final id = note.id;
  if (id != null) {
    final cached = _plainTextCache[id];
    if (cached != null && cached.$1 == note.content) return cached.$2;
  }
  final text = plainTextFromContent(note.content);
  if (id != null) _plainTextCache[id] = (note.content, text);
  return text;
}

/// 문서 JSON에서 글자만 뽑음. JSON이 아니면(예전 메모) 원문 그대로
String plainTextFromContent(String content) {
  if (content.isEmpty) return '';
  final Object? decoded;
  try {
    decoded = jsonDecode(content);
  } catch (_) {
    return content;
  }
  if (decoded is! Map || decoded['document'] is! Map) return content;

  final buffer = StringBuffer();
  void visit(Object? node) {
    if (node is! Map) return;
    final data = node['data'];
    if (data is Map) {
      final delta = data['delta'];
      if (delta is List) {
        for (final op in delta) {
          if (op is Map && op['insert'] is String) buffer.write(op['insert']);
        }
        buffer.write('\n');
      }
      // 코드·파일·위치 블록 글자
      for (final key in const ['code', 'fileName', 'name']) {
        final value = data[key];
        if (value is String && value.isNotEmpty) buffer.writeln(value);
      }
      // 표 칸 글자
      final rows = data['rows'];
      if (rows is List) {
        for (final row in rows) {
          if (row is List) buffer.writeln(row.whereType<String>().join(' '));
        }
      }
    }
    final children = node['children'];
    if (children is List) children.forEach(visit);
  }

  visit(decoded['document']);
  return buffer.toString().replaceAll('￼', ''); // 줄 안의 그림 자리
}

/// 제목·본문 글자·태그에 검색어가 있는지 (대소문자 무시)
bool noteMatchesQuery(Note note, String query) {
  final q = query.toLowerCase();
  if (q.isEmpty) return true;
  return note.title.toLowerCase().contains(q) ||
      notePlainText(note).toLowerCase().contains(q) ||
      note.tags.any((tag) => tag.toLowerCase().contains(q));
}
