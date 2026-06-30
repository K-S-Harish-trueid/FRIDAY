import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class GeminiService {
  static Future<String> sendMessage(
      List<Map<String, String>> messages) async {
    final contents = <Map<String, dynamic>>[];
    String? systemInstruction;

    for (final msg in messages) {
      if (msg['role'] == 'system') {
        systemInstruction = msg['content'];
        continue;
      }
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['content']}
        ],
      });
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': 500,
        'temperature': 0.7,
      },
    };

    if (systemInstruction != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction}
        ],
      };
    }

    final response = await http.post(
      Uri.parse('$geminiBaseUrl?key=$geminiApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['candidates'] as List).first['content']['parts'].first['text']
          as String;
    } else {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }
  }
}
