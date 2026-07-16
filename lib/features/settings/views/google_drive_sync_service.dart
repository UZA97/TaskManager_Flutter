import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/sync/sync_meta.dart';

// googleapis 패키지 없이 Drive REST API 직접 호출
// multipart upload, JSON API 모두 직접 구현
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

  // ── 파일 ID 조회 ──────────────────────────────────────────────

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

  // ── 메타데이터 조회 ───────────────────────────────────────────

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

  // ── 텍스트 파일 업로드 (메타) ─────────────────────────────────

  Future<void> _uploadText(String name, String content) async {
    final existingId = await _getFileId(name);
    final bodyBytes = utf8.encode(content);

    if (existingId != null) {
      // update
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
      // create
      await _multipartUpload(
        name: name,
        mimeType: 'application/json',
        bytes: bodyBytes,
      );
    }
  }

  // ── 바이너리 multipart 업로드 ─────────────────────────────────

  Future<String> _multipartUpload({
    required String name,
    required String mimeType,
    required List<int> bytes,
    String? parentFileId,
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

    final data = jsonDecode(res.body);
    return data['id'] as String;
  }

  // ── 파일 업데이트 ─────────────────────────────────────────────

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

  // ── 파일 다운로드 ─────────────────────────────────────────────

  Future<List<int>?> _downloadFile(String fileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$fileId?alt=media');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }

  // ── Drive 파일 삭제 ───────────────────────────────────────────

  Future<void> _deleteFile(String fileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$fileId');
    await http.delete(uri, headers: _headers);
  }

  // ── Drive Attachments 목록 조회 ───────────────────────────────

  Future<Map<String, String>> _listDriveAttachments() async {
    // name -> fileId
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

  // ── SHA256 체크섬 ─────────────────────────────────────────────

  static String _checksum(List<int> bytes) => sha256.convert(bytes).toString();

  static String _checksumFile(File file) => _checksum(file.readAsBytesSync());

  // Attachment 파일명을 Drive 저장용 키로 변환 (경로 구분자 제거)
  // e.g. "Attachments/1/img.png" -> "ATT_Attachments_1_img.png"
  static String _attachmentDriveKey(String relativePath) =>
      'ATT_${relativePath.replaceAll('/', '_').replaceAll('\\', '_')}';

  static String _attachmentRelativePath(String driveKey) =>
      driveKey.substring(4).replaceAll('_', '/');

  // ── 로컬 경로 헬퍼 ───────────────────────────────────────────

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

  // device_id 조회 또는 생성
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

  // ── 유효한 Attachment 파일 목록 수집 (삭제되지 않은 노트 기준) ──

  static Future<List<File>> _collectValidAttachments(AppDatabase db) async {
    final attDir = await _attachmentsDir();
    if (!attDir.existsSync()) return [];

    // 삭제되지 않은 노트 id 목록
    final notes = await (db.select(
      db.noteTable,
    )..where((t) => t.deletedAt.isNull())).get();
    final validNoteIds = notes.map((n) => n.id.toString()).toSet();

    final files = <File>[];
    await for (final entity in attDir.list(recursive: true)) {
      if (entity is File) {
        // Attachments/{noteId}/filename 구조에서 noteId 추출
        final parts = p.split(p.relative(entity.path, from: attDir.path));
        if (parts.isNotEmpty && validNoteIds.contains(parts.first)) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  // ── 상대 경로 계산 ────────────────────────────────────────────

  static Future<String> _relativeAttachmentPath(File file) async {
    final appDir = await _appSupportDir();
    return p.relative(file.path, from: appDir.path);
  }

  // ══════════════════════════════════════════════════════════════
  // 메인 API
  // ══════════════════════════════════════════════════════════════

  /// Drive 에 백업이 있는지 + 로컬과 비교해서 방향 결정
  /// returns: 'upload' | 'download' | 'none'
  Future<String> decideSyncDirection(AppDatabase db) async {
    final remoteMeta = await fetchRemoteMeta();
    if (remoteMeta == null) return 'upload'; // 첫 sync

    final dbFile = await _dbFile();
    if (!dbFile.existsSync()) return 'download';

    final localChecksum = _checksumFile(dbFile);
    if (localChecksum == remoteMeta.dbChecksum) return 'none';

    final localModified = dbFile.lastModifiedSync();
    if (localModified.isAfter(remoteMeta.lastSync)) return 'upload';
    return 'download';
  }

  /// 업로드
  Future<void> upload(AppDatabase db, {void Function(String)? onStatus}) async {
    onStatus?.call('DB 준비 중...');

    // WAL 체크포인트 — 미반영 트랜잭션을 main DB 파일에 적용
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final dbFile = await _dbFile();
    final dbBytes = dbFile.readAsBytesSync();
    final dbChecksum = _checksum(dbBytes);
    final deviceId = await _getDeviceId(db);

    // DB 업로드
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

    // Attachments 수집
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

      if (driveAttachments.containsKey(driveKey)) {
        // 이미 있음 — skip (체크섬 비교로 변경된 것만 업데이트)
        // 간단히 항상 skip, 필요 시 체크섬 비교로 업그레이드 가능
        continue;
      }

      // 없으면 업로드
      await _multipartUpload(
        name: driveKey,
        mimeType: 'application/octet-stream',
        bytes: fileBytes,
      );
    }

    // Drive에 있는데 유효 목록에 없는 고아 파일 삭제
    final validKeys = newAttachmentMetas
        .map((m) => _attachmentDriveKey(m.relativePath))
        .toSet();
    for (final entry in driveAttachments.entries) {
      if (!validKeys.contains(entry.key)) {
        await _deleteFile(entry.value);
      }
    }

    // 메타 저장
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

  /// 다운로드
  Future<void> download(
    AppDatabase db, {
    void Function(String)? onStatus,
  }) async {
    onStatus?.call('Drive 메타데이터 확인 중...');
    final remoteMeta = await fetchRemoteMeta();
    if (remoteMeta == null) throw Exception('Drive에 백업이 없습니다');

    // 로컬 DB 백업
    onStatus?.call('로컬 DB 백업 중...');
    final dbFile = await _dbFile();
    if (dbFile.existsSync()) {
      final backupFile = File('${dbFile.path}.backup');
      dbFile.copySync(backupFile.path);
    }

    // DB 다운로드
    onStatus?.call('DB 다운로드 중...');
    final dbFileId = await _getFileId(_dbFileName);
    if (dbFileId == null) throw Exception('Drive에 DB 파일이 없습니다');

    final dbBytes = await _downloadFile(dbFileId);
    if (dbBytes == null) throw Exception('DB 다운로드 실패');

    // DB 연결 닫고 파일 교체
    await db.close();
    dbFile.writeAsBytesSync(dbBytes);

    // Attachments 동기화
    onStatus?.call('첨부파일 동기화 중...');
    final appDir = await _appSupportDir();
    final driveAttachments = await _listDriveAttachments();

    // 로컬에 없는 파일 다운로드
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

    // 로컬에 있는데 Drive 목록에 없는 고아 파일 삭제
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
