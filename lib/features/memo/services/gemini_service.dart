import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _apiKey = 'AIzaSyAoq-bHFy5Izp9VB6zJJ93JDj98ieovK90';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  Future<String> ask(String prompt) async {
    final response = await http.post(
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
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini 호출 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
