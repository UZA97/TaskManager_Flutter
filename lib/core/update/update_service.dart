import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

// GitHub 릴리즈 정보를 기반으로 자동 업데이트를 확인하는 서비스 클래스
class UpdateService {
  static const _owner = 'UZA97';
  static const _repo = 'TaskManager_Flutter';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // 예: "1.0.0"
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              // 🌟 중요: GitHub API는 User-Agent를 안 넣으면 403 에러를 뱉음
              'User-Agent': 'Flutter-Update-Service-$_owner-$_repo',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false,
          error: '서버 연결 실패 (결과 코드: ${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body);
      final latestTag = data['tag_name'] as String; // 예: "v1.0.0"
      final latestVersion = latestTag.replaceFirst('v', '');

      final assets = data['assets'] as List<dynamic>;

      // 🌟 Null Safety에 안전하게 asset 찾기 변경
      final targetAsset = assets.cast<Map<String, dynamic>?>().firstWhere(
        (a) => a != null && (a['name'] as String).endsWith('.exe'),
        orElse: () => null,
      );

      if (targetAsset == null) {
        return UpdateCheckResult(hasUpdate: false, error: '설치 파일(.exe) 없음');
      }

      final downloadUrl = targetAsset['browser_download_url'] as String;
      final hasUpdate = _isNewer(latestVersion, currentVersion);

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      return UpdateCheckResult(hasUpdate: false, error: '예외 발생: $e');
    }
  }

  static const _uninstallKey =
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
      r'\{052817F2-E157-48D0-BF2A-AFBBC5A06B65}_is1';

  /// 설치 폴더가 아닌 곳(예전에 복사해 둔 폴더, 바로가기가 가리키는 옛 폴더)의
  /// 예전 exe로 실행됐고 설치 폴더에 더 새 버전이 있으면 그것을 실행함.
  /// 바꿔 실행했으면 true (호출한 쪽은 바로 종료해야 함).
  Future<bool> relaunchInstalledIfNewer() async {
    if (!Platform.isWindows) return false;
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (exeDir.toLowerCase().contains(r'\build\windows\')) return false;
    try {
      String? location;
      String? version;
      for (final root in ['HKLM', 'HKCU']) {
        final result = await Process.run('reg', [
          'query',
          '$root\\$_uninstallKey',
        ]).timeout(const Duration(seconds: 5));
        if (result.exitCode != 0) continue;
        String? value(String name) => RegExp(
          '^\\s*$name\\s+REG_SZ\\s+(.+?)\\s*\$',
          multiLine: true,
        ).firstMatch(result.stdout as String)?.group(1);
        location = value('InstallLocation');
        version = value('DisplayVersion');
        if (location != null) break;
      }
      if (location == null || version == null) return false;
      if (p.equals(p.normalize(location), p.normalize(exeDir))) return false;

      final installedExe = File(
        p.join(location, p.basename(Platform.resolvedExecutable)),
      );
      final current = (await PackageInfo.fromPlatform()).version;
      if (!await installedExe.exists() || !_isNewer(version, current)) {
        return false;
      }
      // --restart: 새 프로세스가 이 프로세스가 끝날 때까지 기다렸다 시작
      await Process.start(installedExe.path, [
        '--restart',
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {
      // 버전 형식이 세 자리가 아니거나 파싱 실패 시 안전장치
      return latest != current;
    }
    return false;
  }

  /// 설치 파일을 받아 조용히 설치하고 앱을 종료함.
  /// 설치가 끝나면 설치 프로그램이 새 버전을 다시 실행함.
  /// 다운로드나 실행에 실패하면 [UpdateException] (앱은 계속 실행됨).
  Future<void> downloadAndInstall(
    String downloadUrl,
    String version, {
    required void Function(double progress) onProgress,
  }) async {
    final installer = await _download(downloadUrl, onProgress);
    await _launchInstaller(installer, version, silent: true);
  }

  /// 조용한 설치가 실패했을 때: 설치 화면을 띄워 직접 설치 (오류가 보임)
  Future<void> installManually(
    UpdateFailure failure, {
    required void Function(double progress) onProgress,
  }) async {
    final installer = await _installerFile();
    final file = await installer.exists() && await _isInstaller(installer)
        ? installer
        : await _download(failure.downloadUrl, onProgress);
    await _launchInstaller(file, failure.version, silent: false);
  }

  Future<File> _installerFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(p.join(tempDir.path, 'TaskManager_Update.exe'));
  }

  /// 이 시간 동안 데이터가 안 오면 다운로드 중단
  static const _idleTimeout = Duration(seconds: 30);

  bool _cancelled = false;
  http.Client? _client;
  void Function()? _cancelDownload;

  /// 진행 중인 다운로드 취소 ([UpdateCancelledException] 발생)
  void cancel() {
    _cancelled = true;
    _cancelDownload?.call();
    _client?.close();
  }

  Future<File> _download(
    String downloadUrl,
    void Function(double progress) onProgress,
  ) async {
    _cancelled = false;
    final file = await _installerFile();
    final client = http.Client();
    _client = client;
    try {
      final http.StreamedResponse response;
      try {
        response = await client
            .send(http.Request('GET', Uri.parse(downloadUrl)))
            .timeout(_idleTimeout);
      } catch (e) {
        if (_cancelled) throw UpdateCancelledException();
        throw UpdateException('다운로드 서버에 연결하지 못했습니다 ($e)');
      }
      if (_cancelled) throw UpdateCancelledException();
      if (response.statusCode != 200) {
        throw UpdateException('다운로드 실패 (결과 코드: ${response.statusCode})');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = file.openWrite();
      final done = Completer<void>();
      _cancelDownload = () {
        if (!done.isCompleted) done.completeError(UpdateCancelledException());
      };
      final sub = response.stream
          .timeout(_idleTimeout)
          .listen(
            (chunk) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (totalBytes > 0) onProgress(receivedBytes / totalBytes);
            },
            onError: (Object e) {
              if (!done.isCompleted) done.completeError(e);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      try {
        await done.future;
      } on UpdateCancelledException {
        rethrow;
      } on TimeoutException {
        throw UpdateException(
          '다운로드가 ${_idleTimeout.inSeconds}초 동안 멈춰 중단했습니다. 네트워크를 확인해 주세요.',
        );
      } catch (e) {
        if (_cancelled) throw UpdateCancelledException();
        throw UpdateException('다운로드 중 연결이 끊겼습니다 ($e)');
      } finally {
        _cancelDownload = null;
        await sub.cancel();
        await sink.close();
      }
      if (_cancelled) throw UpdateCancelledException();

      if (totalBytes > 0 && receivedBytes != totalBytes) {
        throw UpdateException(
          '다운로드가 완전하지 않습니다 ($receivedBytes / $totalBytes 바이트)',
        );
      }
    } finally {
      client.close();
      _client = null;
    }

    if (!await _isInstaller(file)) {
      throw UpdateException('받은 파일이 설치 파일이 아닙니다');
    }
    return file;
  }

  /// 실행 파일(MZ로 시작)인지
  Future<bool> _isInstaller(File file) async {
    try {
      final head = await file.openRead(0, 2).first;
      return head.length == 2 && head[0] == 0x4D && head[1] == 0x5A;
    } catch (_) {
      return false;
    }
  }

  Future<void> _launchInstaller(
    File installer,
    String version, {
    required bool silent,
  }) async {
    final logPath = p.join(installer.parent.path, 'TaskManager_Update.log');
    // 지난 기록이 남아 있으면 이번 설치가 실행됐는지 알 수 없어 지움
    try {
      await File(logPath).delete();
    } catch (_) {}

    // 지금 실행 중인 폴더에 덮어씀. 다른 폴더(예: 복사해 둔 폴더)에서 실행 중이면
    // 기본 설치 폴더에만 깔려서, 바로가기로 다시 열면 예전 버전이 뜨는 문제 방지
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final devBuild = exeDir.toLowerCase().contains(r'\build\windows\');

    try {
      await Process.start(installer.path, [
        if (silent) ...['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        if (!devBuild) '/DIR=$exeDir',
        '/LOG=$logPath',
      ], mode: ProcessStartMode.detached);
    } catch (e) {
      throw UpdateException('설치 프로그램을 실행하지 못했습니다 ($e)');
    }

    // 다음 실행 때 버전이 그대로면 실패 원인을 알려주기 위해 기록
    await _savePending({
      'version': version,
      'log': logPath,
      'installer': installer.path,
      'exe': Platform.resolvedExecutable,
    });

    await windowManager.destroy();
    exit(0);
  }

  Future<File> _pendingFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'pending_update.json'));
  }

  Future<void> _savePending(Map<String, String> data) async {
    try {
      final file = await _pendingFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// 지난번 업데이트가 설치되지 않았으면 그 원인. 설치됐거나 기록이 없으면 null.
  /// 한 번 확인하면 기록을 지움 (같은 실패 안내가 계속 뜨지 않게).
  /// 업데이트 확인이 실패해 [downloadUrl]이 비었으면 기록을 남겨 두고 다음에 확인.
  Future<UpdateFailure?> takeUpdateFailure(String downloadUrl) async {
    if (downloadUrl.isEmpty) return null;
    final Map pending;
    final File file;
    try {
      file = await _pendingFile();
      if (!await file.exists()) return null;
      pending = jsonDecode(await file.readAsString()) as Map;
      await file.delete();
    } catch (_) {
      return null;
    }

    final version = pending['version'] as String? ?? '';
    final current = (await PackageInfo.fromPlatform()).version;
    if (!_isNewer(version, current)) return null; // 설치 성공

    return UpdateFailure(
      version: version,
      currentVersion: current,
      downloadUrl: downloadUrl,
      reason: await _failureReason(pending),
      logPath: pending['log'] as String?,
    );
  }

  /// 설치 기록(Inno Setup 로그)으로 실패 원인 추측
  Future<String> _failureReason(Map pending) async {
    final logPath = pending['log'] as String?;
    final log = logPath == null ? null : File(logPath);
    if (log == null || !await log.exists()) {
      return '설치 프로그램이 시작되지 않았습니다.\n'
          '관리자 권한 확인 창(UAC)에서 "아니요"를 눌렀거나, '
          '백신 프로그램이 설치 파일을 차단했을 수 있습니다.';
    }

    final lines = await _readLog(log);
    final installDir = lines
        .map(
          (l) => RegExp(r'Directory for uninstall files: (.+)$').firstMatch(l),
        )
        .whereType<RegExpMatch>()
        .map((m) => m.group(1)!.trim())
        .firstOrNull;
    final succeeded = lines.any(
      (l) => l.contains('Installation process succeeded'),
    );

    if (succeeded) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      if (installDir != null && !p.equals(installDir, exeDir)) {
        return '새 버전은 "$installDir"에 설치됐지만, '
            '지금 실행 중인 앱은 "$exeDir"에 있습니다.\n'
            '바탕화면·시작 메뉴의 바로가기를 "$installDir"의 '
            'taskmanager.exe로 바꾸거나, 예전 폴더를 지워 주세요.';
      }
      return '설치는 끝났지만 버전이 바뀌지 않았습니다.\n'
          '앱을 완전히 종료(트레이 아이콘 포함)한 뒤 다시 실행해 보세요.';
    }

    final errors = lines
        .where(
          (l) => RegExp(
            r'error|fail|abort|cancel|exception|denied',
            caseSensitive: false,
          ).hasMatch(l),
        )
        .map((l) => l.replaceFirst(RegExp(r'^[\d\-: .]+'), '').trim())
        .toSet()
        .take(5)
        .toList();
    return [
      '설치가 끝나지 않았습니다.',
      if (errors.isNotEmpty) ...errors else '설치 중 취소되었거나 중단되었습니다.',
    ].join('\n');
  }

  /// Inno Setup 로그는 UTF-8(BOM) 또는 시스템 인코딩. 글자가 깨져도 영어 부분만 쓰면 됨.
  Future<List<String>> _readLog(File log) async {
    try {
      final bytes = await log.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true).split(RegExp(r'\r?\n'));
    } catch (_) {
      return const [];
    }
  }
}

class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 사용자가 다운로드를 취소함
class UpdateCancelledException extends UpdateException {
  UpdateCancelledException() : super('다운로드를 취소했습니다');
}

/// 지난번 조용한 설치가 반영되지 않은 경우의 안내 정보
class UpdateFailure {
  UpdateFailure({
    required this.version,
    required this.currentVersion,
    required this.downloadUrl,
    required this.reason,
    this.logPath,
  });

  final String version;
  final String currentVersion;
  final String downloadUrl;
  final String reason;
  final String? logPath;
}

class UpdateCheckResult {
  final bool hasUpdate;
  final String? currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final String? error;

  UpdateCheckResult({
    required this.hasUpdate,
    this.currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.error,
  });
}
