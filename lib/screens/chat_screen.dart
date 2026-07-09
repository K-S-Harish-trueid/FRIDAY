import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Hold-to-talk mic: press starts listening, drag away past the threshold
  // arms a cancel, release either sends (normal) or discards (cancelling).
  static const _cancelSlideThreshold = 80.0;
  bool _isRecording = false;
  bool _isCancelling = false;
  Offset? _holdStartPosition;

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
    final busy = ref.read(chatProvider);
    if (busy.isTyping || busy.isExecutingAction) return;

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
    final busy = ref.read(chatProvider);
    if (busy.isTyping || busy.isExecutingAction) return;

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

  // ── Mic hold-to-talk ─────────────────────────────────────────────────────

  Future<void> _handleMicHoldStart(LongPressStartDetails details) async {
    final busy = ref.read(chatProvider);
    if (busy.isTyping || busy.isExecutingAction) return;

    HapticFeedback.mediumImpact();
    // Instant visual feedback — don't make the user wait on TTS/permission
    // async work before the button even looks like it registered the hold.
    setState(() {
      _isRecording = true;
      _isCancelling = false;
      _holdStartPosition = details.globalPosition;
    });
    unawaited(_ttsService.stop());

    final started = await _speechService.startListening();
    if (!started && mounted) {
      setState(() => _isRecording = false);
      final deniedForever = _speechService.permissionPermanentlyDenied;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deniedForever
                ? "Mic permission is blocked, boss — enable it in system settings."
                : "Couldn't access the mic, boss — permission denied.",
            style: GoogleFonts.rajdhani(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF0f2035),
          behavior: SnackBarBehavior.floating,
          action: deniedForever
              ? SnackBarAction(
                  label: 'SETTINGS',
                  textColor: const Color(0xFF00d4ff),
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
    }
  }

  void _handleMicHoldMove(LongPressMoveUpdateDetails details) {
    if (_holdStartPosition == null) return;
    final dragged =
        (details.globalPosition - _holdStartPosition!).distance >
            _cancelSlideThreshold;
    if (dragged != _isCancelling) {
      setState(() => _isCancelling = dragged);
      if (dragged) HapticFeedback.heavyImpact();
    }
  }

  void _handleMicHoldEnd(LongPressEndDetails details) {
    final cancelling = _isCancelling;
    setState(() {
      _isRecording = false;
      _isCancelling = false;
      _holdStartPosition = null;
    });
    if (cancelling) {
      _speechService.cancelListening();
    } else {
      // Finalizes the current listen; the recognized text (if any) flows
      // through SpeechService.onResult -> _sendFromSpeech.
      _speechService.stopListening();
    }
  }

  void _handleMicHoldCancel() {
    setState(() {
      _isRecording = false;
      _isCancelling = false;
      _holdStartPosition = null;
    });
    _speechService.cancelListening();
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
              _buildInputBar(
                isExecutingAction: state.isExecutingAction,
                pendingLocationChoice: state.pendingLocationChoice,
                busy: state.isTyping || state.isExecutingAction,
              ),
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
                  ? 'Hold the mic to talk, or type "help" to begin'
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

  Widget _buildInputBar({
    required bool isExecutingAction,
    required bool pendingLocationChoice,
    required bool busy,
  }) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Action HUD (visible while a device action is executing) ──
          if (isExecutingAction) const _ActionHud(),
          // ── Location choice (backend wants location, no place given) ──
          if (pendingLocationChoice)
            _LocationChoiceCard(
              onUseMyLocation: () =>
                  ref.read(chatProvider.notifier).useMyLocation(),
              onEnterManually: () {
                ref.read(chatProvider.notifier).dismissLocationChoice();
                _focusNode.requestFocus();
              },
            ),
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
                  isCancelling: _isCancelling,
                  onStop: () {
                    _speechService.cancelListening();
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
                key: const Key('chat_text_field'),
                controller: _textCtrl,
                focusNode: _focusNode,
                enabled: !busy,
                style: GoogleFonts.rajdhani(
                  color: Colors.white.withValues(alpha: busy ? 0.4 : 1.0),
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: busy ? 'FRIDAY is responding…' : 'Ask me anything, boss...',
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
                onSubmitted: busy ? null : (_) => _send(),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            // ── Mic button (hold to talk, slide away to cancel) ──
            ValueListenableBuilder<SpeechStatus>(
              valueListenable: _speechService.status,
              builder: (_, status, _) {
                final isProcessing = status == SpeechStatus.processing;
                final idleColor = const Color(0xFF00d4ff).withValues(alpha: 0.4);
                final micColor = _isCancelling
                    ? const Color(0xFFff6b35)
                    : _isRecording
                        ? const Color(0xFF00ff88)
                        : isProcessing
                            ? const Color(0xFFff6b35)
                            : idleColor;
                final iconColor = _isCancelling || _isRecording
                    ? micColor
                    : const Color(0xFF00d4ff).withValues(alpha: 0.55);
                return RawGestureDetector(
                  key: const Key('chat_mic_button'),
                  gestures: busy
                      ? const {}
                      : {
                          LongPressGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                  LongPressGestureRecognizer>(
                            // Shorter than the default 500ms so holding the
                            // mic feels immediate, push-to-talk style.
                            () => LongPressGestureRecognizer(
                              duration: const Duration(milliseconds: 150),
                            ),
                            (instance) {
                              instance
                                ..onLongPressStart = _handleMicHoldStart
                                ..onLongPressMoveUpdate = _handleMicHoldMove
                                ..onLongPressEnd = _handleMicHoldEnd
                                ..onLongPressCancel = _handleMicHoldCancel;
                            },
                          ),
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0f2035),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: micColor, width: 1.5),
                      boxShadow: (_isRecording || _isCancelling)
                          ? [
                              BoxShadow(
                                color: micColor.withValues(alpha: 0.3),
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
                            _isCancelling
                                ? Icons.delete_outline
                                : _isRecording
                                    ? Icons.mic
                                    : Icons.mic_none,
                            color: iconColor,
                            size: 22,
                          ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            // ── Send button (arc reactor) ──
            GestureDetector(
              key: const Key('chat_send_button'),
              onTap: busy ? null : _send,
              child: AnimatedOpacity(
                opacity: busy ? 0.35 : 1.0,
                duration: const Duration(milliseconds: 200),
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
                      boxShadow: busy
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF00d4ff)
                                    .withValues(alpha: 0.3),
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
  final bool isCancelling;
  final VoidCallback onStop;

  const _VoiceOverlay({
    required this.status,
    required this.partialText,
    required this.isCancelling,
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
    final cancelling = widget.isCancelling;
    final accent = cancelling
        ? const Color(0xFFff6b35)
        : isListening
            ? const Color(0xFF00ff88)
            : const Color(0xFFff6b35);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0a1628),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 14),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Waveform bars, cancel icon, or spinner
              SizedBox(
                width: 40,
                height: 28,
                child: cancelling
                    ? Icon(Icons.delete_outline, color: accent, size: 24)
                    : isListening
                        ? _buildBars()
                        : _buildSpinner(),
              ),
              const SizedBox(width: 12),
              // Status label + live text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cancelling
                          ? 'RELEASE TO CANCEL'
                          : isListening
                              ? 'LISTENING — RELEASE TO SEND'
                              : 'PROCESSING',
                      style: GoogleFonts.orbitron(
                        color: accent,
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cancelling
                          ? 'Message will be discarded'
                          : widget.partialText.isNotEmpty
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

// ── Location choice — backend needs a place, none was named ──────────────────

class _LocationChoiceCard extends StatelessWidget {
  final VoidCallback onUseMyLocation;
  final VoidCallback onEnterManually;

  const _LocationChoiceCard({
    required this.onUseMyLocation,
    required this.onEnterManually,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF00d4ff), size: 15),
              const SizedBox(width: 8),
              Text(
                'WHICH LOCATION, BOSS?',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00d4ff),
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _choiceButton(
                  icon: Icons.my_location,
                  label: 'MY LOCATION',
                  color: const Color(0xFF00ff88),
                  onTap: onUseMyLocation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _choiceButton(
                  icon: Icons.edit_outlined,
                  label: 'ENTER MANUALLY',
                  color: const Color(0xFF00d4ff),
                  onTap: onEnterManually,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                color: color,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}