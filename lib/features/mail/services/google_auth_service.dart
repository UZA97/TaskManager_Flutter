import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:http/http.dart' as http;

final json = jsonDecode(File('config/google_oauth.json').readAsStringSync());

final _clientId = json['installed']['client_id'];
final _clientSecret = json['installed']['client_secret'];

class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    // static으로 변경
    params: GoogleSignInParams(
      clientId: _clientId,
      clientSecret: _clientSecret,
      scopes: ['email', 'profile', 'https://mail.google.com/'],
    ),
  );

  Future<GoogleAuthResult?> signIn() async {
    try {
      final credentials = await _googleSignIn.signIn();
      if (credentials == null) return null;
      final email = await _getEmail(credentials.accessToken);
      return GoogleAuthResult(
        accessToken: credentials.accessToken,
        refreshToken: credentials.refreshToken,
        email: email,
      );
    } catch (e) {
      print('signIn error: $e');
      return null;
    }
  }

  Future<String?> refreshAccessToken(String refreshToken) async {
    try {
      final credentials = await _googleSignIn.silentSignIn();
      return credentials?.accessToken;
    } catch (e) {
      return null;
    }
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
