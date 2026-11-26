import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/database/database.dart';
import 'package:taskmanager/features/map/data/map_repository.dart';
import 'package:taskmanager/features/memo/data/note_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('map tag and place can be edited', () async {
    final repo = MapRepository(db);
    final food = await repo.createTag('맛집', '#E53935');
    final cafe = await repo.createTag('카페', '#4A90E2');
    await repo.addPlace(
      MapPlace(
        name: '가게',
        address: '서울',
        lat: 37.5,
        lng: 127,
        tagId: food.id!,
        createdAt: '2026-11-26',
      ),
    );
    final place = (await repo.getAllPlaces()).single;

    await repo.updateTag(food.id!, name: '음식', color: '#4CAF50');
    await repo.updatePlace(place.id!, name: '단골 가게', tagId: cafe.id!);

    final tags = {for (final t in await repo.getAllTags()) t.id: t};
    expect((tags[food.id]!.name, tags[food.id]!.color), ('음식', '#4CAF50'));
    final edited = (await repo.getAllPlaces()).single;
    expect((edited.name, edited.tagId), ('단골 가게', cafe.id));
    expect((edited.address, edited.lat), ('서울', 37.5)); // 나머지는 그대로
  });

  test('note list reads no content and never wipes it on save', () async {
    final repo = NoteRepository(db);
    final note = await repo.createNote();
    await repo.saveNote(note.copyWith(title: '제목', content: '{"본문":1}'));
    await repo.saveNoteTags(note.id!, ['태그']);

    final summary = (await repo.getNoteSummaries()).single;
    expect(summary.title, '제목');
    expect(summary.content, '');
    expect(summary.contentLoaded, isFalse);
    expect(summary.tags, ['태그']);

    // 목록용 메모로 저장(제목 바꾸기 등)해도 본문은 그대로
    await repo.saveNote(summary.copyWith(title: '새 제목'));
    final full = (await repo.getNoteById(note.id!))!;
    expect(full.title, '새 제목');
    expect(full.content, '{"본문":1}');
    expect(full.contentLoaded, isTrue);

    // 본문을 넣어 저장하면 반영
    await repo.saveNote(full.copyWith(content: '{"새":2}'));
    expect((await repo.getNoteById(note.id!))!.content, '{"새":2}');

    expect(await repo.getNoteTitles(), {note.id!: '새 제목'});
    await repo.deleteNote(note.id!);
    expect(await repo.getNoteSummaries(), isEmpty);
    expect(await repo.getNoteTitles(), isEmpty);
  });
}
