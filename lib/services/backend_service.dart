import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/action.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class BackendService {
  static const _timeout = Duration(seconds: 30);

  /// Sends the running conversation history (most recent message last) to
  /// the backend. Returns (response text, conversationId, action). `action`
  /// is non-null when the backend's tool-calling agent wants the device to
  /// do something (open maps, fetch GPS location).
  static Future<(String, String?, Action?)> sendMessage(
    List<Map<String, String>> history,
    String? conversationId,
  ) async {
    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'messages': history,
            'conversation_id': conversationId,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['response'] as String;
      final rawId = data['conversation_id'];
      final convId = rawId is String ? rawId : null;
      final rawAction = data['action'];
      final action = rawAction is Map<String, dynamic>
          ? Action.fromJson(rawAction)
          : null;
      return (text, convId, action);
    }
    throw Exception('Backend ${response.statusCode}');
  }

  /// Returns conversations sorted newest first.
  static Future<List<ConversationSummary>> listConversations() async {
    final response = await http
        .get(Uri.parse('$backendBaseUrl/conversations/'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      final summaries = list
          .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return summaries;
    }
    throw Exception('Failed to list conversations');
  }

  /// Fetches all messages for a conversation.
  static Future<List<Message>> getMessages(String conversationId) async {
    final response = await http
        .get(Uri.parse('$backendBaseUrl/conversations/$conversationId/messages'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return Message(
          id: m['id'] as String,
          role: m['role'] as String,
          content: m['content'] as String,
          timestamp: DateTime.parse(m['timestamp'] as String),
        );
      }).toList();
    }
    throw Exception('Failed to load messages');
  }

  static Future<void> deleteConversation(String conversationId) async {
    final response = await http
        .delete(Uri.parse('$backendBaseUrl/conversations/$conversationId'))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation');
    }
  }
}
