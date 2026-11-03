import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

final _apiKey = AppConfig.geminiApiKey;
final _baseUrl = AppConfig.geminiBaseUrl;

class GeminiService {
  static const timeout = Duration(seconds: 60);

  Future<String> ask(String prompt) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
          }),
        )
        .timeout(timeout); // 응답이 없으면 무한 대기하지 않도록

    if (response.statusCode != 200) {
      print('Error Body: ${response.body}');
      throw Exception('Gemini 호출 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
