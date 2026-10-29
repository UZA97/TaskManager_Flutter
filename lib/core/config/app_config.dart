import 'dart:convert';

import 'package:flutter/services.dart';

/// config/*.json (git에는 올리지 않는 키 파일)을 앱 에셋으로 읽음.
///
/// `File('config/...')`처럼 상대 경로로 읽으면 "현재 작업 폴더" 기준이라
/// 개발 PC(flutter run, 프로젝트 폴더에서 실행)에서만 동작하고
/// 설치된 앱에서는 파일을 찾지 못함. 에셋은 빌드 결과물
/// (data/flutter_assets)에 포함되어 어디서 실행해도 읽힘.
class AppConfig {
  AppConfig._();

  static late final Map<String, dynamic> _googleOAuth;
  static late final Map<String, dynamic> _gemini;

  /// main()에서 runApp 전에 한 번 호출
  static Future<void> load() async {
    _googleOAuth = await _read('config/google_oauth.json');
    _gemini = await _read('config/gemini_service.json');
  }

  static Future<Map<String, dynamic>> _read(String asset) async {
    final json = jsonDecode(await rootBundle.loadString(asset)) as Map;
    return Map<String, dynamic>.from(json['installed'] as Map);
  }

  static String get googleClientId => _googleOAuth['client_id'] as String;
  static String get googleClientSecret =>
      _googleOAuth['client_secret'] as String;

  static String get geminiApiKey => _gemini['_apiKey'] as String;
  static String get geminiBaseUrl => _gemini['_baseUrl'] as String;
}
