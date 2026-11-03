import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/sync/sync_meta.dart';

class GoogleDriveSyncService {
  static const _driveApiBase = 'https://www.googleapis.com/drive/v3';
  static const _driveUploadBase = 'https://www.googleapis.com/upload/drive/v3';
  static const _dbFileName = 'taskmanager.sqlite';
  static const _metaFileName = 'sync_meta.json';
  static const _appDataFolder = 'appDataFolder';
  static const _hashCacheFileName = 'sync_hash_cache.json';

  final String accessToken;

  GoogleDriveSyncService({required this.accessToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  // 실패 응답이면 예외 — 실패했는데 "완료"로 표시되는 것 방지
  static void _check(http.Response res, String action) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    print('Drive $action 실패: ${res.statusCode} ${res.body}');
    if (res.statusCode == 401) {
      throw Exception('Google 인증이 만료되었습니다. 다시 연동해주세요');
    }
    if (res.statusCode == 403) {
      throw Exception('Drive 권한이 없습니다. 설정에서 Google 계정을 다시 연동해주세요');
    }
    throw Exception('$action 실패 (${res.statusCode})');
  }

  Future<String?> _getFileId(String name) async {
    final uri = Uri.parse(
      '$_driveApiBase/files'
      '?spaces=appDataFolder'
      '&q=name%3D%22$name%22'
      '&fields=files(id,name)',
    );
    final res = await http.get(uri, headers: _headers);
    _check(res, '파일 조회');
    final data = jsonDecode(res.body);
    final files = data['files'] as List<dynamic>;
    if (files.isEmpty) return null;
    return files.first['id'] as String;
  }

  Future<SyncMeta?> fetchRemoteMeta() async {
    final fileId = await _getFileId(_metaFileName);
    if (fileId == null) return null;

    final uri = Uri.parse('$_driveApiBase/files/$fileId?alt=media');
    final res = await http.get(uri, headers: _headers);
    _check(res, '메타데이터 다운로드');

    try {
      return SyncMeta.decode(res.body);
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadText(String name, String content) async {
    final existingId = await _getFileId(name);
    final bodyBytes = utf8.encode(content);

    if (existingId != null) {
      final uri = Uri.parse(
        '$_driveUploadBase/files/$existingId?uploadType=media',
      );
      final res = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: bodyBytes,
      );
      _check(res, '메타데이터 업로드');
    } else {
      await _multipartUpload(
        name: name,
        mimeType: 'application/json',
        bytes: bodyBytes,
      );
    }
  }

  Future<String> _multipartUpload({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final boundary = '-------TaskManagerBoundary';
    final metadata = jsonEncode({
      'name': name,
      'parents': [_appDataFolder],
    });

    // 큰 파일도 리스트 연결 없이 한 번에 조립
    final builder = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: $mimeType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final body = builder.takeBytes();

    final uri = Uri.parse(
      '$_driveUploadBase/files?uploadType=multipart&fields=id',
    );
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
        'Content-Length': '${body.length}',
      },
      body: body,
    );

    _check(res, '$name 업로드');

    final data = jsonDecode(res.body);
    return data['id'] as String? ?? ''; // null 안전하게
  }

  Future<void> _updateFile(
    String fileId,
    List<int> bytes,
    String mimeType,
  ) async {
    final uri = Uri.parse('$_driveUploadBase/files/$fileId?uploadType=media');
    final res = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': mimeType,
      },
      body: bytes,
    );
    _check(res, '파일 업데이트');
  }

  Future<Uint8List?> _downloadFile(String fileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$fileId?alt=media');
    final res = await http.get(uri, headers: _headers);
    _check(res, '파일 다운로드');
    return res.bodyBytes;
  }

  Future<void> _deleteFile(String fileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$fileId');
    final res = await http.delete(uri, headers: _headers);
    if (res.statusCode != 404) _check(res, '파일 삭제');
  }

  Future<Map<String, String>> _listDriveAttachments() async {
    final result = <String, String>{};
    String? pageToken;

    do {
      var url =
          '$_driveApiBase/files'
          '?spaces=appDataFolder'
          '&q=name+contains+%22ATT_%22'
          '&fields=nextPageToken,files(id,name)'
          '&pageSize=100';
      if (pageToken != null) url += '&pageToken=$pageToken';

      final res = await http.get(Uri.parse(url), headers: _headers);
      _check(res, '첨부파일 목록 조회');

      final data = jsonDecode(res.body);
      final files = data['files'] as List<dynamic>;
      for (final f in files) {
        result[f['name'] as String] = f['id'] as String;
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    return result;
  }

  // 해시는 UI 멈춤 방지를 위해 별도 isolate에서 계산
  static Future<String> _checksumBytes(Uint8List bytes) =>
      Isolate.run(() => sha256.convert(bytes).toString());

  static Future<Map<String, String>> _checksumPaths(List<String> paths) {
    if (paths.isEmpty) return Future.value({});
    return Isolate.run(() async {
      final result = <String, String>{};
      for (final path in paths) {
        final digest = await sha256.bind(File(path).openRead()).first;
        result[path] = digest.toString();
      }
      return result;
    });
  }

  // 로컬 해시 캐시: relPath → {s: 크기, m: 수정시각(ms), c: 체크섬}
  static Future<File> _hashCacheFile() async {
    final dir = await _appSupportDir();
    return File(p.join(dir.path, _hashCacheFileName));
  }

  static Future<Map<String, dynamic>> _loadHashCache() async {
    try {
      final f = await _hashCacheFile();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveHashCache(Map<String, dynamic> cache) async {
    try {
      final f = await _hashCacheFile();
      await f.writeAsString(jsonEncode(cache), flush: true);
    } catch (e) {
      debugPrint('해시 캐시 저장 실패: $e');
    }
  }

  // 크기+수정시각이 캐시와 같으면 재해시 생략
  static Future<List<AttachmentMeta>> _attachmentChecksums(
    List<File> files,
  ) async {
    final cache = await _loadHashCache();
    final newCache = <String, dynamic>{};
    final relPaths = <String, String>{}; // 절대경로 → 상대경로
    final stats = <String, FileStat>{};
    final toHash = <String>[];

    for (final file in files) {
      final relPath = await _relativeAttachmentPath(file);
      final stat = await file.stat();
      relPaths[file.path] = relPath;
      stats[file.path] = stat;
      final cached = cache[relPath];
      if (cached is Map &&
          cached['s'] == stat.size &&
          cached['m'] == stat.modified.millisecondsSinceEpoch &&
          cached['c'] is String) {
        newCache[relPath] = cached;
      } else {
        toHash.add(file.path);
      }
    }

    final hashed = await _checksumPaths(toHash);
    for (final entry in hashed.entries) {
      final stat = stats[entry.key]!;
      newCache[relPaths[entry.key]!] = {
        's': stat.size,
        'm': stat.modified.millisecondsSinceEpoch,
        'c': entry.value,
      };
    }
    await _saveHashCache(newCache);

    return [
      for (final file in files)
        AttachmentMeta(
          relativePath: relPaths[file.path]!,
          checksum: (newCache[relPaths[file.path]!] as Map)['c'] as String,
        ),
    ];
  }

  static String _attachmentDriveKey(String relativePath) =>
      'ATT_${relativePath.replaceAll('/', '_').replaceAll('\\', '_')}';

  static Future<Directory> _appSupportDir() async =>
      getApplicationSupportDirectory();

  static Future<File> _dbFile() async {
    final dir = await _appSupportDir();
    return File(p.join(dir.path, 'taskmanager.sqlite'));
  }

  static Future<Directory> _attachmentsDir() async {
    final dir = await _appSupportDir();
    return Directory(p.join(dir.path, 'Attachments'));
  }

  static Future<String> _getDeviceId(AppDatabase db) async {
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('sync_device_id'))).getSingleOrNull();
    if (row != null) return row.value;

    final id = const Uuid().v4();
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: 'sync_device_id', value: id),
        );
    return id;
  }

  static Future<List<File>> _collectValidAttachments(AppDatabase db) async {
    final attDir = await _attachmentsDir();
    if (!await attDir.exists()) return [];

    final notes = await (db.select(
      db.noteTable,
    )..where((t) => t.deletedAt.isNull())).get();
    final validNoteIds = notes.map((n) => n.id.toString()).toSet();

    final files = <File>[];
    await for (final entity in attDir.list(recursive: true)) {
      if (entity is File) {
        final parts = p.split(p.relative(entity.path, from: attDir.path));
        if (parts.isNotEmpty && validNoteIds.contains(parts.first)) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  static Future<String> _relativeAttachmentPath(File file) async {
    final appDir = await _appSupportDir();
    return p.relative(file.path, from: appDir.path);
  }

  Future<String> decideSyncDirection(AppDatabase db) async {
    final remoteMeta = await fetchRemoteMeta();
    if (remoteMeta == null) return 'upload';

    final dbFile = await _dbFile();
    if (!await dbFile.exists()) return 'download';

    final localChecksum = (await _checksumPaths([dbFile.path]))[dbFile.path];
    if (localChecksum == remoteMeta.dbChecksum) return 'none';

    final localModified = await dbFile.lastModified();
    if (localModified.isAfter(remoteMeta.lastSync)) return 'upload';
    return 'download';
  }

  Future<void> upload(AppDatabase db, {void Function(String)? onStatus}) async {
    onStatus?.call('DB 준비 중...');
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final dbFile = await _dbFile();
    final dbBytes = await dbFile.readAsBytes();
    final dbChecksum = await _checksumBytes(dbBytes);
    final deviceId = await _getDeviceId(db);

    onStatus?.call('첨부파일 확인 중...');
    final validFiles = await _collectValidAttachments(db);
    final localMetas = await _attachmentChecksums(validFiles);
    final driveAttachments = await _listDriveAttachments();
    final remoteMeta = await fetchRemoteMeta();
    final remoteChecksums = {
      for (final m in remoteMeta?.attachments ?? <AttachmentMeta>[])
        m.relativePath: m.checksum,
    };

    // 올려야 할 첨부 (Drive에 없거나 체크섬이 다름)
    final pending = <int>[];
    for (var i = 0; i < localMetas.length; i++) {
      final m = localMetas[i];
      final key = _attachmentDriveKey(m.relativePath);
      if (!driveAttachments.containsKey(key) ||
          remoteChecksums[m.relativePath] != m.checksum) {
        pending.add(i);
      }
    }

    onStatus?.call('DB 업로드 중...');
    final existingDbId = await _getFileId(_dbFileName);
    if (existingDbId != null) {
      await _updateFile(existingDbId, dbBytes, 'application/octet-stream');
    } else {
      await _multipartUpload(
        name: _dbFileName,
        mimeType: 'application/octet-stream',
        bytes: dbBytes,
      );
    }

    // DB 직후 메타 갱신 — 이후 실패해도 다른 기기 다운로드가 막히지 않게
    // 아직 안 올린 첨부는 이전 원격 체크섬(없으면 '')으로 기록 → 다음 업로드 때 재시도
    final pendingSet = pending.toSet();
    await _uploadMeta(deviceId, dbChecksum, [
      for (var i = 0; i < localMetas.length; i++)
        pendingSet.contains(i)
            ? AttachmentMeta(
                relativePath: localMetas[i].relativePath,
                checksum: remoteChecksums[localMetas[i].relativePath] ?? '',
              )
            : localMetas[i],
    ]);

    for (var n = 0; n < pending.length; n++) {
      final i = pending[n];
      final driveKey = _attachmentDriveKey(localMetas[i].relativePath);
      onStatus?.call('첨부파일 업로드 중... (${n + 1}/${pending.length})');
      final fileBytes = await validFiles[i].readAsBytes();
      final existingId = driveAttachments[driveKey];
      if (existingId != null) {
        await _updateFile(existingId, fileBytes, 'application/octet-stream');
      } else {
        await _multipartUpload(
          name: driveKey,
          mimeType: 'application/octet-stream',
          bytes: fileBytes,
        );
      }
    }

    // 고아 파일 삭제
    final validKeys = localMetas
        .map((m) => _attachmentDriveKey(m.relativePath))
        .toSet();
    for (final entry in driveAttachments.entries) {
      if (!validKeys.contains(entry.key)) {
        await _deleteFile(entry.value);
      }
    }

    onStatus?.call('메타데이터 저장 중...');
    await _uploadMeta(deviceId, dbChecksum, localMetas);
    onStatus?.call('업로드 완료');
  }

  Future<void> _uploadMeta(
    String deviceId,
    String dbChecksum,
    List<AttachmentMeta> attachments,
  ) async {
    final meta = SyncMeta(
      lastSync: DateTime.now().toUtc(),
      deviceId: deviceId,
      dbChecksum: dbChecksum,
      attachments: attachments,
    );
    await _uploadText(_metaFileName, meta.encode());
  }

  Future<void> download(
    AppDatabase db, {
    void Function(String)? onStatus,
  }) async {
    onStatus?.call('Drive 메타데이터 확인 중...');
    final remoteMeta = await fetchRemoteMeta();
    if (remoteMeta == null) throw Exception('Drive에 백업이 없습니다');

    onStatus?.call('DB 다운로드 중...');
    final dbFileId = await _getFileId(_dbFileName);
    if (dbFileId == null) throw Exception('Drive에 DB 파일이 없습니다');

    final dbBytes = await _downloadFile(dbFileId);
    if (dbBytes == null) throw Exception('DB 다운로드 실패');
    if (!_isSqliteFile(dbBytes)) {
      throw Exception('Drive의 DB 파일이 손상되었습니다');
    }
    if (remoteMeta.dbChecksum.isNotEmpty &&
        await _checksumBytes(dbBytes) != remoteMeta.dbChecksum) {
      // Drive 업로드는 원자적이라 파일 자체는 온전함 — 메타 갱신 전에 중단된 경우
      debugPrint('Drive DB 체크섬이 메타데이터와 다름 — 그대로 진행');
      onStatus?.call('메타데이터 불일치 — Drive의 최신 DB로 진행합니다');
      await Future.delayed(const Duration(seconds: 1));
    }

    onStatus?.call('로컬 DB 백업 중...');
    final dbFile = await _dbFile();
    final backupFile = File('${dbFile.path}.backup');
    var hasBackup = false;
    if (await dbFile.exists()) {
      // WAL 내용을 본 파일에 반영한 뒤 복사해야 백업이 완전함
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await dbFile.copy(backupFile.path);
      hasBackup = true;
    }

    await db.close();
    // 여기부터는 DB가 닫혔으므로 무슨 일이 있어도 재시작
    try {
      try {
        await _replaceDbFile(dbFile, dbBytes);
      } catch (e) {
        debugPrint('DB 교체 실패: $e');
        if (hasBackup) {
          onStatus?.call('DB 교체 실패 — 백업에서 복원합니다');
          await _replaceDbFile(dbFile, await backupFile.readAsBytes());
        }
        rethrow;
      }

      try {
        await _downloadAttachments(remoteMeta, onStatus);
      } catch (e) {
        // 첨부 일부 실패 — DB는 유지하고 재시작
        debugPrint('첨부파일 동기화 실패: $e');
        onStatus?.call('첨부파일 일부 동기화 실패: $e');
        await Future.delayed(const Duration(seconds: 2));
      }

      onStatus?.call('다운로드 완료 — 앱을 재시작합니다');
      await Future.delayed(const Duration(seconds: 1)); // 메시지 보여주고
    } catch (e) {
      onStatus?.call('오류: $e — 앱을 재시작합니다');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      await _restartApp();
    }
  }

  static Future<void> _replaceDbFile(File dbFile, List<int> bytes) async {
    // 이전 DB의 WAL/SHM이 남아 있으면 새 DB 위에 적용되므로 제거
    for (final suffix in ['-wal', '-shm']) {
      final f = File('${dbFile.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await dbFile.writeAsBytes(bytes, flush: true);
  }

  Future<void> _downloadAttachments(
    SyncMeta remoteMeta,
    void Function(String)? onStatus,
  ) async {
    onStatus?.call('첨부파일 동기화 중...');
    final appDir = await _appSupportDir();
    final driveAttachments = await _listDriveAttachments();

    for (final meta in remoteMeta.attachments) {
      final localFile = File(p.join(appDir.path, meta.relativePath));
      if (!await localFile.exists()) {
        final driveKey = _attachmentDriveKey(meta.relativePath);
        final fileId = driveAttachments[driveKey];
        if (fileId == null) continue;

        final bytes = await _downloadFile(fileId);
        if (bytes == null) continue;

        await localFile.parent.create(recursive: true);
        await localFile.writeAsBytes(bytes);
      }
    }

    // 고아 파일 삭제
    final validPaths = remoteMeta.attachments
        .map((m) => p.join(appDir.path, m.relativePath))
        .toSet();
    final attDir = await _attachmentsDir();
    if (await attDir.exists()) {
      await for (final entity in attDir.list(recursive: true)) {
        if (entity is File && !validPaths.contains(entity.path)) {
          await entity.delete();
        }
      }
    }
  }

  static bool _isSqliteFile(List<int> bytes) {
    const header = 'SQLite format 3';
    if (bytes.length < header.length) return false;
    return utf8.decode(bytes.sublist(0, header.length), allowMalformed: true) ==
        header;
  }

  // 단일 인스턴스 mutex 때문에 그냥 띄우면 바로 종료됨
  // → --restart로 띄우면 새 프로세스가 이 프로세스가 끝날 때까지 기다렸다 시작
  static Future<void> _restartApp() async {
    await Process.start(Platform.resolvedExecutable, [
      '--restart',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}
