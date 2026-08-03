import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

final json = jsonDecode(File('config/gemini_service.json').readAsStringSync());
final _apiKey = json['installed']['_apiKey'];
final _baseUrl = json['installed']['_baseUrl'];

class GeminiService {
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
      print('Error Body: ${response.body}');
      throw Exception('Gemini 호출 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
