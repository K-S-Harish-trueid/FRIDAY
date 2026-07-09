import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/action.dart';
import '../models/message.dart';
import '../commands/friday_commands.dart';
import '../services/action_service.dart';
import '../services/backend_service.dart';

// Sentinel used so copyWith can explicitly set conversationId to null.
const _unset = Object();

class ChatState {
  final List<Message> messages;
  final bool isTyping;
  final String activeProvider;
  final String? conversationId;
  final bool isExecutingAction;
  final bool pendingLocationChoice;

  const ChatState({
    required this.messages,
    required this.isTyping,
    required this.activeProvider,
    this.conversationId,
    this.isExecutingAction = false,
    this.pendingLocationChoice = false,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isTyping,
    String? activeProvider,
    Object? conversationId = _unset,
    bool? isExecutingAction,
    bool? pendingLocationChoice,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      activeProvider: activeProvider ?? this.activeProvider,
      conversationId: identical(conversationId, _unset)
          ? this.conversationId
          : conversationId as String?,
      isExecutingAction: isExecutingAction ?? this.isExecutingAction,
      pendingLocationChoice:
          pendingLocationChoice ?? this.pendingLocationChoice,
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
    final saved = prefs.getString(providerPrefsKey);
    if (saved != null && saved != state.activeProvider) {
      state = state.copyWith(activeProvider: saved);
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    // Block a new message while one is already in flight (typing or
    // running a device action) — prevents overlapping/out-of-order sends.
    if (state.isTyping || state.isExecutingAction) return;

    final userMsg = Message(role: 'user', content: content);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      pendingLocationChoice: false,
    );

    // ── 1. Local commands (no API call) ──────────────────────────────────────
    final result = await FridayCommands.handle(content);

    if (result.handled) {
      if (result.type == CommandType.clear) {
        final clearMsg = Message(
          role: 'assistant',
          content: result.message!,
          isCommand: true,
        );
        _deleteActiveConversation();
        state = ChatState(
          messages: [clearMsg],
          isTyping: false,
          activeProvider: state.activeProvider,
          conversationId: null,
        );
        return;
      }

      if (result.type == CommandType.newChat) {
        // Unlike clear, this preserves the old conversation in Mission Log —
        // just starts a fresh one, same as the drawer's "NEW MISSION" button.
        final newMsg = Message(
          role: 'assistant',
          content: result.message!,
          isCommand: true,
        );
        state = ChatState(
          messages: [newMsg],
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
      final history = state.messages
          .where((m) => !m.isCommand)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final (response, newConvId, action) =
          await BackendService.sendMessage(history, state.conversationId);

      final assistantMsg = Message(role: 'assistant', content: response);
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isTyping: false,
        conversationId: newConvId ?? state.conversationId,
      );

      if (action != null) {
        if (action.type == 'get_location') {
          // Don't grab GPS silently — let the user pick "my location" vs.
          // typing a place in manually.
          state = state.copyWith(pendingLocationChoice: true);
        } else {
          await _runAction(action);
        }
      }
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

  // ── 3. Device action (maps / location) dispatched by the backend agent ────
  Future<void> _runAction(Action action) async {
    state = state.copyWith(isExecutingAction: true);
    try {
      final followUp = await ActionService.execute(action);
      state = state.copyWith(isExecutingAction: false);
      if (followUp != null) {
        await sendMessage(followUp);
      }
    } catch (_) {
      state = state.copyWith(isExecutingAction: false);
    }
  }

  /// User tapped "My Location" on the pending location-choice card — fetch
  /// GPS and send it as a follow-up message.
  Future<void> useMyLocation() async {
    state = state.copyWith(pendingLocationChoice: false);
    await _runAction(const Action(type: 'get_location'));
  }

  /// User tapped "Enter Manually" — just dismiss the card; the UI focuses
  /// the text field so they can type a place themselves.
  void dismissLocationChoice() {
    state = state.copyWith(pendingLocationChoice: false);
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
    await prefs.setString(providerPrefsKey, provider);
  }

  void clearChat() {
    _deleteActiveConversation();
    state = ChatState(
      messages: [],
      isTyping: false,
      activeProvider: state.activeProvider,
      conversationId: null,
    );
  }

  /// Best-effort delete of the conversation being cleared so it doesn't
  /// linger in the Mission Log. Fire-and-forget — the local UI reset
  /// happens regardless of whether the backend call succeeds.
  void _deleteActiveConversation() {
    final id = state.conversationId;
    if (id == null) return;
    unawaited(BackendService.deleteConversation(id).catchError((_) {}));
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);
