import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class GroqService {
  static Future<String> sendMessage(
      List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse(groqEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqApiKey',
      },
      body: jsonEncode({
        'model': groqModel,
        'messages': messages,
        'max_tokens': 500,
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['choices'] as List).first['message']['content'] as String;
    } else {
      throw Exception('Groq error ${response.statusCode}: ${response.body}');
    }
  }
}
