import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

class MapTag {
  final int? id;
  final String name;
  final String color;
  const MapTag({this.id, required this.name, required this.color});
}

class MapPlace {
  final int? id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int tagId;
  final String createdAt;
  const MapPlace({
    this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.tagId,
    required this.createdAt,
  });
}

class MapRepository {
  final AppDatabase _db;
  MapRepository(this._db);

  Future<List<MapTag>> getAllTags() async {
    final rows = await _db.select(_db.mapTagTable).get();
    return rows
        .map((r) => MapTag(id: r.id, name: r.name, color: r.color))
        .toList();
  }

  Future<MapTag> createTag(String name, String color) async {
    final id = await _db
        .into(_db.mapTagTable)
        .insert(MapTagTableCompanion.insert(name: name, color: Value(color)));
    return MapTag(id: id, name: name, color: color);
  }

  Future<void> deleteTag(int id) async {
    await (_db.delete(
      _db.mapPlaceTable,
    )..where((t) => t.tagId.equals(id))).go();
    await (_db.delete(_db.mapTagTable)..where((t) => t.id.equals(id))).go();
  }

  Future<List<MapPlace>> getPlacesByTag(int tagId) async {
    final rows = await (_db.select(
      _db.mapPlaceTable,
    )..where((t) => t.tagId.equals(tagId))).get();
    return rows
        .map(
          (r) => MapPlace(
            id: r.id,
            name: r.name,
            address: r.address,
            lat: r.lat,
            lng: r.lng,
            tagId: r.tagId,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  Future<List<MapPlace>> getAllPlaces() async {
    final rows = await _db.select(_db.mapPlaceTable).get();
    return rows
        .map(
          (r) => MapPlace(
            id: r.id,
            name: r.name,
            address: r.address,
            lat: r.lat,
            lng: r.lng,
            tagId: r.tagId,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  Future<void> addPlace(MapPlace place) async {
    await _db
        .into(_db.mapPlaceTable)
        .insert(
          MapPlaceTableCompanion.insert(
            name: place.name,
            address: Value(place.address),
            lat: place.lat,
            lng: place.lng,
            tagId: place.tagId,
            createdAt: place.createdAt,
          ),
        );
  }

  Future<void> deletePlace(int id) async {
    await (_db.delete(_db.mapPlaceTable)..where((t) => t.id.equals(id))).go();
  }
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MapRepository(db);
});
