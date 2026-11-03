import 'dart:io';

/// Windows 시작 시 자동 실행 (현재 사용자 Run 레지스트리).
/// 설정은 레지스트리 자체에 있으므로 DB에 따로 저장하지 않음.
class AutostartService {
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'TaskManager';

  static String get _command => '"${Platform.resolvedExecutable}"';

  /// 이 실행 파일로 등록돼 있는지
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('reg', ['query', _key, '/v', _name]);
      if (result.exitCode != 0) return false;
      final out = (result.stdout as String).toLowerCase();
      return out.contains(Platform.resolvedExecutable.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// 켜기/끄기. 실패하면 false.
  static Future<bool> setEnabled(bool enabled) async {
    if (!Platform.isWindows) return false;
    try {
      final result = enabled
          ? await Process.run('reg', [
              'add',
              _key,
              '/v',
              _name,
              '/t',
              'REG_SZ',
              '/d',
              _command,
              '/f',
            ])
          : await Process.run('reg', ['delete', _key, '/v', _name, '/f']);
      // 끌 때 값이 원래 없으면 실패 코드지만 결과는 같음
      return result.exitCode == 0 || !enabled;
    } catch (_) {
      return false;
    }
  }
}
