import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
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

  final String accessToken;

  GoogleDriveSyncService({required this.accessToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Future<String?> _getFileId(String name) async {
    final uri = Uri.parse(
      '$_driveApiBase/files'
      '?spaces=appDataFolder'
      '&q=name%3D%22$name%22'
      '&fields=files(id,name)',
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
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
    if (res.statusCode != 200) return null;

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
      await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: bodyBytes,
      );
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

    final body =
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: $mimeType\r\n\r\n',
        ) +
        bytes +
        utf8.encode('\r\n--$boundary--');

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

    print('multipart upload 응답: ${res.statusCode} / ${res.body}'); // 추가

    final data = jsonDecode(res.body);
    return data['id'] as String? ?? ''; // null 안전하게
  }

  Future<void> _updateFile(
    String fileId,
    List<int> bytes,
    String mimeType,
  ) async {
    final uri = Uri.parse('$_driveUploadBase/files/$fileId?uploadType=media');
    await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': mimeType,
      },
      body: bytes,
    );
  }

  Future<List<int>?> _downloadFile(String fileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$fileId?alt=media');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }

  Future<void> _deleteFile(String fileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$fileId');
    await http.delete(uri, headers: _headers);
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
      if (res.statusCode != 200) break;

      final data = jsonDecode(res.body);
      final files = data['files'] as List<dynamic>;
      for (final f in files) {
        result[f['name'] as String] = f['id'] as String;
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    return result;
  }

  static String _checksum(List<int> bytes) => sha256.convert(bytes).toString();
  static String _checksumFile(File file) => _checksum(file.readAsBytesSync());

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
    if (!attDir.existsSync()) return [];

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
    if (!dbFile.existsSync()) return 'download';

    final localChecksum = _checksumFile(dbFile);
    if (localChecksum == remoteMeta.dbChecksum) return 'none';

    final localModified = dbFile.lastModifiedSync();
    if (localModified.isAfter(remoteMeta.lastSync)) return 'upload';
    return 'download';
  }

  Future<void> upload(AppDatabase db, {void Function(String)? onStatus}) async {
    onStatus?.call('DB 준비 중...');
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final dbFile = await _dbFile();
    final dbBytes = dbFile.readAsBytesSync();
    final dbChecksum = _checksum(dbBytes);
    final deviceId = await _getDeviceId(db);

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

    onStatus?.call('첨부파일 동기화 중...');
    final validFiles = await _collectValidAttachments(db);
    final driveAttachments = await _listDriveAttachments();
    final newAttachmentMetas = <AttachmentMeta>[];

    for (final file in validFiles) {
      final relPath = await _relativeAttachmentPath(file);
      final driveKey = _attachmentDriveKey(relPath);
      final fileBytes = file.readAsBytesSync();
      final fileChecksum = _checksum(fileBytes);

      newAttachmentMetas.add(
        AttachmentMeta(relativePath: relPath, checksum: fileChecksum),
      );

      if (driveAttachments.containsKey(driveKey)) continue;

      await _multipartUpload(
        name: driveKey,
        mimeType: 'application/octet-stream',
        bytes: fileBytes,
      );
    }

    // 고아 파일 삭제
    final validKeys = newAttachmentMetas
        .map((m) => _attachmentDriveKey(m.relativePath))
        .toSet();
    for (final entry in driveAttachments.entries) {
      if (!validKeys.contains(entry.key)) {
        await _deleteFile(entry.value);
      }
    }

    onStatus?.call('메타데이터 저장 중...');
    final meta = SyncMeta(
      lastSync: DateTime.now().toUtc(),
      deviceId: deviceId,
      dbChecksum: dbChecksum,
      attachments: newAttachmentMetas,
    );
    await _uploadText(_metaFileName, meta.encode());
    onStatus?.call('업로드 완료');
  }

  Future<void> download(
    AppDatabase db, {
    void Function(String)? onStatus,
  }) async {
    onStatus?.call('Drive 메타데이터 확인 중...');
    final remoteMeta = await fetchRemoteMeta();
    if (remoteMeta == null) throw Exception('Drive에 백업이 없습니다');

    onStatus?.call('로컬 DB 백업 중...');
    final dbFile = await _dbFile();
    if (dbFile.existsSync()) {
      final backupFile = File('${dbFile.path}.backup');
      dbFile.copySync(backupFile.path);
    }

    onStatus?.call('DB 다운로드 중...');
    final dbFileId = await _getFileId(_dbFileName);
    if (dbFileId == null) throw Exception('Drive에 DB 파일이 없습니다');

    final dbBytes = await _downloadFile(dbFileId);
    if (dbBytes == null) throw Exception('DB 다운로드 실패');

    await db.close();
    dbFile.writeAsBytesSync(dbBytes);

    onStatus?.call('첨부파일 동기화 중...');
    final appDir = await _appSupportDir();
    final driveAttachments = await _listDriveAttachments();

    for (final meta in remoteMeta.attachments) {
      final localFile = File(p.join(appDir.path, meta.relativePath));
      if (!localFile.existsSync()) {
        final driveKey = _attachmentDriveKey(meta.relativePath);
        final fileId = driveAttachments[driveKey];
        if (fileId == null) continue;

        final bytes = await _downloadFile(fileId);
        if (bytes == null) continue;

        localFile.parent.createSync(recursive: true);
        localFile.writeAsBytesSync(bytes);
      }
    }

    // 고아 파일 삭제
    final validPaths = remoteMeta.attachments
        .map((m) => p.join(appDir.path, m.relativePath))
        .toSet();
    final attDir = await _attachmentsDir();
    if (attDir.existsSync()) {
      await for (final entity in attDir.list(recursive: true)) {
        if (entity is File && !validPaths.contains(entity.path)) {
          entity.deleteSync();
        }
      }
    }

    onStatus?.call('다운로드 완료 — 앱을 재시작합니다');
  }
}
