import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class OwnService {
  static Future<String> sendMessage(
      List<Map<String, String>> messages) async {
    String? system;
    final history = <Map<String, String>>[];

    for (final m in messages) {
      if (m['role'] == 'system') {
        system = m['content'];
      } else {
        history.add({'role': m['role']!, 'content': m['content']!});
      }
    }

    final response = await http.post(
      Uri.parse(ownApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': history,
        if (system != null) 'system': system,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['response'] as String;
    } else {
      throw Exception('Own API error ${response.statusCode}: ${response.body}');
    }
  }
}
