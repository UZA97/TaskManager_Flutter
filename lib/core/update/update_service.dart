import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class UpdateService {
  static const _owner = 'UZA97';
  static const _repo = 'TaskManager_Flutter';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // 예: "1.0.0"
      print('현재 버전: $currentVersion'); // 추가
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          // 🌟 중요: GitHub API는 User-Agent를 안 넣으면 403 에러를 뱉음
          'User-Agent': 'Flutter-Update-Service-$_owner-$_repo',
        },
      );
      print('GitHub 응답: ${response.statusCode}'); // 추가
      print('GitHub body: ${response.body}'); // 추가
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

  Future<void> downloadAndInstall(
    String downloadUrl, {
    required void Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final installerPath = p.join(tempDir.path, 'TaskManager_Update.exe');
    final file = File(installerPath);

    final request = http.Request('GET', Uri.parse(downloadUrl));
    final response = await request.send();
    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final sink = file.openWrite();
    await response.stream.listen((chunk) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }
    }).asFuture();
    await sink.close();

    // 🌟 Inno Setup 인스톨러 백그라운드 무소음 실행 후 즉시 종료
    await Process.start(installerPath, [
      '/VERYSILENT',
      '/RESTARTAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    await windowManager.destroy();
    exit(0);
  }
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
