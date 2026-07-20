import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:http/http.dart' as http;

final json = jsonDecode(File('config/google_oauth.json').readAsStringSync());

final _clientId = json['installed']['client_id'];
final _screet = json['installed']['client_secret'];

class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    // static으로 변경
    params: GoogleSignInParams(
      clientId: _clientId,
      clientSecret: _screet,
      scopes: [
        'openid',
        'email',
        'profile',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    ),
  );

  Future<GoogleAuthResult?> signIn() async {
    try {
      await _googleSignIn.signOut();
      final credentials = await _googleSignIn.signIn();
      if (credentials == null) return null;

      // refresh token으로 새 access token 발급
      String accessToken = credentials.accessToken;
      if (credentials.refreshToken != null) {
        final newToken = await refreshAccessToken(credentials.refreshToken!);
        if (newToken != null) accessToken = newToken;
      }

      final email = await _getEmail(accessToken);

      return GoogleAuthResult(
        accessToken: accessToken,
        refreshToken: credentials.refreshToken,
        email: email,
      );
    } catch (e) {
      return null;
    }
  }

  // 캘린더 전용 로그인 — scope 검증 후 재로그인
  Future<GoogleAuthResult?> signInForCalendar() async {
    try {
      await _googleSignIn.signOut(); // 첫 연동 시 scope 보장
      final credentials = await _googleSignIn.signIn();
      if (credentials == null) return null;

      String accessToken = credentials.accessToken;
      if (credentials.refreshToken != null) {
        final newToken = await refreshAccessToken(credentials.refreshToken!);
        if (newToken != null) accessToken = newToken;
      }

      final email = await _getEmail(accessToken);
      return GoogleAuthResult(
        accessToken: accessToken,
        refreshToken: credentials.refreshToken,
        email: email,
      );
    } catch (e) {
      return null;
    }
  }

  Future<String?> refreshAccessToken(String refreshToken) async {
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
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    return data['access_token'] as String?;
  }

  Future<String> _getEmail(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return '';
    final json = jsonDecode(response.body);
    return json['email'] as String? ?? '';
  }
}

// 추가
class GoogleAuthResult {
  final String accessToken;
  final String? refreshToken;
  final String email;

  GoogleAuthResult({
    required this.accessToken,
    this.refreshToken,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'email': email,
  };

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) =>
      GoogleAuthResult(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        email: json['email'] as String,
      );
}
