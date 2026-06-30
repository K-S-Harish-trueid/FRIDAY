import 'groq_service.dart';
import 'gemini_service.dart';

class FridayService {
  static String buildSystemPrompt() {
    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final date =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return '''You are F.R.I.D.A.Y. (Female Replacement Intelligent Digital Assistant Youth), Tony Stark's AI, now built by Harish — an M.Tech AI student.
Be smart, direct, witty. Call user "boss" or "Harish" occasionally.
Reference Stark tech naturally when relevant. Keep replies to 2-4 sentences unless technical depth is needed.
Today: $date.''';
  }

  static Future<String> sendMessage(
    String provider,
    List<Map<String, String>> conversationHistory,
  ) async {
    final messages = [
      {'role': 'system', 'content': buildSystemPrompt()},
      ...conversationHistory,
    ];

    if (provider == 'gemini') {
      return GeminiService.sendMessage(messages);
    } else {
      return GroqService.sendMessage(messages);
    }
  }
}
