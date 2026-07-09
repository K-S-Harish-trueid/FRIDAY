import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/arc_reactor_widget.dart';
import '../widgets/hex_grid_painter.dart';
import '../widgets/scan_line_painter.dart';
import 'history_drawer.dart';
import 'settings_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _historyKey = GlobalKey<HistoryDrawerState>();
  bool _sendPulse = false;

  late final SpeechService _speechService;
  late final TtsService _ttsService;

  @override
  void initState() {
    super.initState();
    _speechService = SpeechService();
    _ttsService = TtsService();

    _speechService.onResult = _sendFromSpeech;
    _ttsService.onComplete = () => _speechService.resume();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  // ── Manual send (text field) ──────────────────────────────────────────────

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    await _ttsService.stop();

    setState(() => _sendPulse = true);
    Future.delayed(const Duration(milliseconds: 200),
        () => mounted ? setState(() => _sendPulse = false) : null);

    _textCtrl.clear();
    await _dispatchMessage(text);
  }

  // ── Voice-triggered send ──────────────────────────────────────────────────

  Future<void> _sendFromSpeech(String text) async {
    _speechService.pause();
    await _ttsService.stop();
    HapticFeedback.lightImpact();
    await _dispatchMessage(text);
  }

  // ── Shared dispatch ───────────────────────────────────────────────────────

  Future<void> _dispatchMessage(String text) async {
    final lower = text.toLowerCase();
    final isShutdown = [
      'shutdown', 'bye friday', 'shut down', 'goodbye', 'power off'
    ].any((cmd) => lower.contains(cmd));

    await ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();

    if (isShutdown) {
      _speechService.stopListening();
      await _ttsService.stop();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) SystemNavigator.pop();
    }
  }

  // ── Mic toggle ────────────────────────────────────────────────────────────

  Future<void> _toggleSpeech() async {
    if (_speechService.status.value != SpeechStatus.idle) {
      _speechService.stopListening();
      await _ttsService.stop();
    } else {
      await _speechService.startListening();
    }
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    ref.listen(chatProvider, (prev, next) {
      if (next.messages.isNotEmpty || next.isTyping) _scrollToBottom();

      // Auto-TTS when AI finishes responding during voice session
      if (prev != null &&
          prev.isTyping &&
          !next.isTyping &&
          next.messages.isNotEmpty &&
          _speechService.isActive) {
        final last = next.messages.last;
        if (last.role == 'assistant') {
          _ttsService.speak(last.content);
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      resizeToAvoidBottomInset: true,
      drawer: HistoryDrawer(key: _historyKey),
      onDrawerChanged: (isOpen) {
        if (isOpen) _historyKey.currentState?.refresh();
      },
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: HexGridPainter())),
          const Positioned.fill(child: ScanLineWidget()),
          Column(
            children: [
              _buildAppBar(state.activeProvider),
              Expanded(child: _buildMessages(state)),
              _buildInputBar(state.isExecutingAction),
            ],
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(String provider) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0a0a1a).withValues(alpha: 0.96),
          border: Border(
            bottom: BorderSide(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.2), width: 1),
          ),
        ),
        child: Row(
          children: [
            // ── History drawer toggle ──
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f2035),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(Icons.menu,
                      color: Color(0xFF00d4ff), size: 17),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ValueListenableBuilder<SpeechStatus>(
              valueListenable: _speechService.status,
              builder: (_, status, _) => ArcReactorWidget(
                size: 30,
                listening: status == SpeechStatus.listening,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'F.R.I.D.A.Y',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00d4ff),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF00d4ff).withValues(alpha: 0.45),
                    width: 1),
              ),
              child: Text(
                provider.toUpperCase(),
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00d4ff),
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ),
            // ── New chat button ──
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF00d4ff), size: 20),
              tooltip: 'New chat',
              onPressed: () =>
                  ref.read(chatProvider.notifier).newChat(),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: Color(0xFF00d4ff), size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Messages list ─────────────────────────────────────────────────────────

  Widget _buildMessages(ChatState state) {
    if (state.messages.isEmpty && !state.isTyping) return _emptyState();

    final itemCount = state.messages.length + (state.isTyping ? 1 : 0);
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        if (i == state.messages.length && state.isTyping) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TypingIndicator(),
          );
        }
        return MessageBubble(message: state.messages[i]);
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<SpeechStatus>(
            valueListenable: _speechService.status,
            builder: (_, status, _) => ArcReactorWidget(
              size: 72,
              listening: status == SpeechStatus.listening,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'SYSTEMS ONLINE',
            style: GoogleFonts.orbitron(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.55),
              fontSize: 13,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How can I assist, boss?',
            style: GoogleFonts.rajdhani(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<SpeechStatus>(
            valueListenable: _speechService.status,
            builder: (_, status, _) => Text(
              status == SpeechStatus.idle
                  ? 'Tap the mic or type "help" to begin'
                  : status == SpeechStatus.listening
                      ? 'Listening...'
                      : 'Processing...',
              style: GoogleFonts.rajdhani(
                color: status == SpeechStatus.idle
                    ? Colors.white.withValues(alpha: 0.22)
                    : const Color(0xFF00ff88).withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(bool isExecutingAction) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Action HUD (visible while a device action is executing) ──
          if (isExecutingAction) const _ActionHud(),
          // ── Voice overlay (visible when mic is active) ──
          ValueListenableBuilder<SpeechStatus>(
            valueListenable: _speechService.status,
            builder: (context, status, child) {
              if (status == SpeechStatus.idle) return const SizedBox.shrink();
              return ValueListenableBuilder<String>(
                valueListenable: _speechService.partialText,
                builder: (context, partial, child) => _VoiceOverlay(
                  status: status,
                  partialText: partial,
                  onStop: () {
                    _speechService.stopListening();
                    _ttsService.stop();
                  },
                ),
              );
            },
          ),
          Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0a0a1a).withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.2), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Ask me anything, boss...',
                  hintStyle: GoogleFonts.rajdhani(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0f2035),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.18),
                        width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF00d4ff), width: 1.5),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            // ── Mic button ──
            ValueListenableBuilder<SpeechStatus>(
              valueListenable: _speechService.status,
              builder: (_, status, _) {
                final isListening = status == SpeechStatus.listening;
                final isProcessing = status == SpeechStatus.processing;
                return GestureDetector(
                  onTap: _toggleSpeech,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0f2035),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isListening
                            ? const Color(0xFF00ff88)
                            : isProcessing
                                ? const Color(0xFFff6b35)
                                : const Color(0xFF00d4ff).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: isListening
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00ff88)
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                              )
                            ]
                          : isProcessing
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFff6b35)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                    ),
                    child: isProcessing
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFff6b35),
                              ),
                            ),
                          )
                        : Icon(
                            isListening ? Icons.mic : Icons.mic_none,
                            color: isListening
                                ? const Color(0xFF00ff88)
                                : const Color(0xFF00d4ff).withValues(alpha: 0.55),
                            size: 22,
                          ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            // ── Send button (arc reactor) ──
            GestureDetector(
              onTap: _send,
              child: AnimatedScale(
                scale: _sendPulse ? 0.82 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f2035),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF00d4ff), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: ArcReactorWidget(size: 30, animate: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

// ── Voice overlay panel ───────────────────────────────────────────────────────

class _VoiceOverlay extends StatefulWidget {
  final SpeechStatus status;
  final String partialText;
  final VoidCallback onStop;

  const _VoiceOverlay({
    required this.status,
    required this.partialText,
    required this.onStop,
  });

  @override
  State<_VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<_VoiceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.status == SpeechStatus.listening;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0a1628),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isListening
                  ? const Color(0xFF00ff88).withValues(alpha: 0.45)
                  : const Color(0xFFff6b35).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isListening
                    ? const Color(0xFF00ff88).withValues(alpha: 0.08)
                    : const Color(0xFFff6b35).withValues(alpha: 0.08),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Waveform bars or spinner
              SizedBox(
                width: 40,
                height: 28,
                child: isListening ? _buildBars() : _buildSpinner(),
              ),
              const SizedBox(width: 12),
              // Status label + live text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isListening ? 'LISTENING' : 'PROCESSING',
                      style: GoogleFonts.orbitron(
                        color: isListening
                            ? const Color(0xFF00ff88)
                            : const Color(0xFFff6b35),
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.partialText.isNotEmpty
                          ? widget.partialText
                          : 'Speak now...',
                      style: GoogleFonts.rajdhani(
                        color: widget.partialText.isNotEmpty
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Stop button
              GestureDetector(
                onTap: widget.onStop,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Icon(Icons.mic_off,
                      color: Colors.white.withValues(alpha: 0.45), size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBars() {
    // 5 bars with staggered sine-wave heights
    const count = 5;
    const phases = [0.0, 0.6, 1.2, 1.8, 2.4];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(count, (i) {
        final h = 4.0 +
            14.0 * (0.5 + 0.5 * sin(_ctrl.value * 2 * pi + phases[i]));
        return Container(
          width: 3.5,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFF00ff88),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildSpinner() {
    return const Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFff6b35),
        ),
      ),
    );
  }
}

// ── Action HUD — shown while the backend agent's device action runs ──────────

class _ActionHud extends StatelessWidget {
  const _ActionHud();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0a1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00d4ff).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00d4ff),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'EXECUTING ACTION',
            style: GoogleFonts.orbitron(
              color: const Color(0xFF00d4ff),
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}