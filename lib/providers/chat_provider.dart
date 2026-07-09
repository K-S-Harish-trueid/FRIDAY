import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/message.dart';
import '../commands/friday_commands.dart';
import '../services/backend_service.dart';

const _providerPrefsKey = 'active_provider';

// Sentinel used so copyWith can explicitly set conversationId to null.
const _unset = Object();

class ChatState {
  final List<Message> messages;
  final bool isTyping;
  final String activeProvider;
  final String? conversationId;

  const ChatState({
    required this.messages,
    required this.isTyping,
    required this.activeProvider,
    this.conversationId,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isTyping,
    String? activeProvider,
    Object? conversationId = _unset,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      activeProvider: activeProvider ?? this.activeProvider,
      conversationId: identical(conversationId, _unset)
          ? this.conversationId
          : conversationId as String?,
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
    final saved = prefs.getString(_providerPrefsKey);
    if (saved != null && saved != state.activeProvider) {
      state = state.copyWith(activeProvider: saved);
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMsg = Message(role: 'user', content: content);
    state = state.copyWith(messages: [...state.messages, userMsg]);

    // ── 1. Local commands (no API call) ──────────────────────────────────────
    final result = await FridayCommands.handle(content);

    if (result.handled) {
      if (result.type == CommandType.clear) {
        final clearMsg = Message(
          role: 'assistant',
          content: result.message!,
          isCommand: true,
        );
        // Clear also resets the backend conversation so a new one starts next.
        state = ChatState(
          messages: [clearMsg],
          isTyping: false,
          activeProvider: state.activeProvider,
          conversationId: null,
        );
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

    // ── 2. BackendService (only path — all LLM calls happen server-side) ──────
    try {
      final (response, newConvId) =
          await BackendService.sendMessage(content, state.conversationId);

      final assistantMsg = Message(role: 'assistant', content: response);
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isTyping: false,
        // Keep existing id if backend returned null (local command on server).
        conversationId: newConvId ?? state.conversationId,
      );
    } catch (e) {
      final errMsg = Message(
        role: 'assistant',
        content: "Suit comms offline, boss — can't reach base. ($e)",
      );
      state = state.copyWith(
        messages: [...state.messages, errMsg],
        isTyping: false,
      );
    }
  }

  /// Load a historical conversation from the backend into the chat view.
  void loadConversation(String id, List<Message> messages) {
    state = ChatState(
      messages: messages,
      isTyping: false,
      activeProvider: state.activeProvider,
      conversationId: id,
    );
  }

  /// Start a fresh chat — clears messages and resets the backend conversation.
  void newChat() {
    state = ChatState(
      messages: [],
      isTyping: false,
      activeProvider: state.activeProvider,
      conversationId: null,
    );
  }

  Future<void> changeProvider(String provider) async {
    state = state.copyWith(activeProvider: provider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerPrefsKey, provider);
  }

  void clearChat() {
    state = ChatState(
      messages: [],
      isTyping: false,
      activeProvider: state.activeProvider,
      conversationId: null,
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);
