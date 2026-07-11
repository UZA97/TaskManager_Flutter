import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OutlookAuthService {
  static const _clientId = '48bcec69-5b85-4687-a809-0f03e8e9a823';
  static const _scope =
      'https://graph.microsoft.com/Mail.Read '
      'https://graph.microsoft.com/User.Read '
      'offline_access';

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<OutlookAuthResult?> signIn() async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final server = await HttpServer.bind('localhost', 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port';

    final authUrl = Uri.https(
      'login.microsoftonline.com',
      '/consumers/oauth2/v2.0/authorize',
      {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scope,
        'response_mode': 'query',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    await launchUrl(authUrl, mode: LaunchMode.externalApplication);

    String? code;
    await for (final request in server) {
      code = request.uri.queryParameters['code'];
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write('<html><body><h2>로그인 완료! 앱으로 돌아가세요.</h2></body></html>');
      await request.response.close();
      break;
    }
    await server.close();

    if (code == null) return null;

    return await _exchangeCodeForTokens(
      code: code,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
    );
  }

  Future<OutlookAuthResult?> _exchangeCodeForTokens({
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final response = await http.post(
      Uri.parse(
        'https://login.microsoftonline.com/consumers/oauth2/v2.0/token',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
        'scope': _scope,
      },
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;

    // Microsoft Graph로 이메일 가져오기
    final email = await _getEmail(accessToken);

    return OutlookAuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
    );
  }

  Future<String> _getEmail(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return '';
    final data = jsonDecode(response.body);
    return data['mail'] as String? ??
        data['userPrincipalName'] as String? ??
        '';
  }

  Future<String?> refreshAccessToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse(
        'https://login.microsoftonline.com/consumers/oauth2/v2.0/token',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
        'scope': _scope,
      },
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    return data['access_token'] as String?;
  }
}

class OutlookAuthResult {
  final String accessToken;
  final String? refreshToken;
  final String email;

  OutlookAuthResult({
    required this.accessToken,
    this.refreshToken,
    required this.email,
  });
}
