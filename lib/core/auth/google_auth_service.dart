import 'dart:convert';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:http/http.dart' as http;
import '../database/database.dart';
import 'dart:io';

final json = jsonDecode(File('config/google_oauth.json').readAsStringSync());

final _clientId = json['installed']['client_id'];
final _screet = json['installed']['client_secret'];

const _keyAccessToken = 'google_access_token';
const _keyRefreshToken = 'google_refresh_token';
const _keyEmail = 'google_email';

// 구글 OAuth / 토큰 저장 / 토큰 갱신을 담당하는 유일한 곳
// UI·기능 코드에서는 직접 쓰지 말고 googleAccountProvider를 통해 사용
class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    params: GoogleSignInParams(
      // 기본 1분은 계정 선택 + 7개 권한 동의를 하기에 짧음
      timeout: const Duration(minutes: 5),
      clientId: _clientId,
      clientSecret: _screet,
      scopes: [
        'openid',
        'email',
        'profile',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/gmail.modify',
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    ),
  );

  // 메모리 캐시 — 만료 전까지는 refresh 요청을 보내지 않음
  static String? _cachedToken;
  static DateTime? _cachedExpiry;
  static Future<String?>? _refreshing;

  static Future<GoogleAuthResult?> signIn() async {
    try {
      await _googleSignIn.signOut(); // 계정 선택 + scope 동의 화면 보장
      final credentials = await _googleSignIn.signIn();
      if (credentials == null) return null;

      final email = await _getEmail(credentials.accessToken);
      if (email.isEmpty) return null;

      _cachedToken = credentials.accessToken;
      _cachedExpiry = DateTime.now().add(const Duration(minutes: 50));
      return GoogleAuthResult(
        accessToken: credentials.accessToken,
        refreshToken: credentials.refreshToken,
        email: email,
      );
    } catch (e) {
      print('구글 로그인 실패: $e');
      return null;
    }
  }

  static Future<void> saveTokens(
    AppDatabase db,
    GoogleAuthResult result,
  ) async {
    await _write(db, _keyAccessToken, result.accessToken);
    // 이미 동의한 계정은 refresh token이 안 내려올 수 있음 → 기존 값 유지
    if (result.refreshToken != null) {
      await _write(db, _keyRefreshToken, result.refreshToken!);
    }
    await _write(db, _keyEmail, result.email);
  }

  static Future<void> clearTokens(AppDatabase db) async {
    _cachedToken = null;
    _cachedExpiry = null;
    for (final key in [_keyAccessToken, _keyRefreshToken, _keyEmail]) {
      await (db.delete(db.settingTable)..where((t) => t.key.equals(key))).go();
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  // 유효한 access token 반환. 갱신 불가(로그아웃/권한 취소)면 null
  static Future<String?> getAccessToken(AppDatabase db) {
    final expiry = _cachedExpiry;
    if (_cachedToken != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry)) {
      return Future.value(_cachedToken);
    }
    // 메일/캘린더가 동시에 요청해도 refresh는 한 번만
    return _refreshing ??= _refresh(db).whenComplete(() => _refreshing = null);
  }

  static Future<String?> _refresh(AppDatabase db) async {
    final refreshToken = await _read(db, _keyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _screet,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );
      if (response.statusCode != 200) {
        print('구글 토큰 갱신 실패: ${response.statusCode} ${response.body}');
        // 권한 취소/만료된 refresh token → 로그아웃 상태로 정리
        if (response.body.contains('invalid_grant')) await clearTokens(db);
        return null;
      }
      final data = jsonDecode(response.body);
      final token = data['access_token'] as String?;
      if (token == null) return null;

      final expiresIn = data['expires_in'] as int? ?? 3600;
      _cachedToken = token;
      // 만료 직전 요청 실패 방지용 여유 1분
      _cachedExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
      await _write(db, _keyAccessToken, token);
      return token;
    } catch (e) {
      print('구글 토큰 갱신 오류: $e');
      return null;
    }
  }

  static Future<String?> getSavedEmail(AppDatabase db) => _read(db, _keyEmail);

  static Future<bool> hasRefreshToken(AppDatabase db) async =>
      await _read(db, _keyRefreshToken) != null;

  static Future<String?> _read(AppDatabase db, String key) async {
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  static Future<void> _write(AppDatabase db, String key, String value) async {
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(key: key, value: value),
        );
  }

  static Future<String> _getEmail(String accessToken) async {
    final response = await http
        .get(
          Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return '';
    final json = jsonDecode(response.body);
    return json['email'] as String? ?? '';
  }
}

class GoogleAuthResult {
  final String accessToken;
  final String? refreshToken;
  final String email;

  GoogleAuthResult({
    required this.accessToken,
    this.refreshToken,
    required this.email,
  });
}
