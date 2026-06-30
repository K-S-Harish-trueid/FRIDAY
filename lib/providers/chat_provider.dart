import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/message.dart';
import '../commands/friday_commands.dart';
import '../services/friday_service.dart';

class ChatState {
  final List<Message> messages;
  final bool isTyping;
  final String activeProvider;

  const ChatState({
    required this.messages,
    required this.isTyping,
    required this.activeProvider,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isTyping,
    String? activeProvider,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      activeProvider: activeProvider ?? this.activeProvider,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    Future.microtask(_loadProvider);
    return const ChatState(
      messages: [],
      isTyping: false,
      activeProvider: defaultProvider,
    );
  }

  Future<void> _loadProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('active_provider') ?? defaultProvider;
    state = state.copyWith(activeProvider: provider);
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMsg = Message(role: 'user', content: content);
    state = state.copyWith(messages: [...state.messages, userMsg]);

    final result = await FridayCommands.handle(content);

    if (result.handled) {
      if (result.type == CommandType.clear) {
        final clearMsg = Message(
          role: 'assistant',
          content: result.message!,
          isCommand: true,
        );
        state = state.copyWith(messages: [clearMsg]);
        return;
      }

      final cmdMsg = Message(
        role: 'assistant',
        content: result.message!,
        isCommand: true,
      );
      state = state.copyWith(messages: [...state.messages, cmdMsg]);
      return;
    }

    state = state.copyWith(isTyping: true);

    try {
      final history = state.messages
          .where((m) => !m.isCommand)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response = await FridayService.sendMessage(
        state.activeProvider,
        history,
      );

      final assistantMsg = Message(role: 'assistant', content: response);
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isTyping: false,
      );
    } catch (e) {
      final errMsg = Message(
        role: 'assistant',
        content: 'Suit comms offline, boss. Check your API key or connection.',
        isCommand: false,
      );
      state = state.copyWith(
        messages: [...state.messages, errMsg],
        isTyping: false,
      );
    }
  }

  Future<void> changeProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_provider', provider);
    state = state.copyWith(activeProvider: provider);
  }

  void clearChat() {
    state = state.copyWith(messages: []);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);
