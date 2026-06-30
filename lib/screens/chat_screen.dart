import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/arc_reactor_widget.dart';
import '../widgets/hex_grid_painter.dart';
import '../widgets/scan_line_painter.dart';
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
  bool _sendPulse = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() => _sendPulse = true);
    Future.delayed(const Duration(milliseconds: 200),
        () => mounted ? setState(() => _sendPulse = false) : null);

    _textCtrl.clear();

    final lower = text.toLowerCase();
    final isShutdown = ['shutdown', 'bye friday', 'shut down', 'goodbye', 'power off']
        .any((cmd) => lower.contains(cmd));

    await ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();

    if (isShutdown) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) SystemNavigator.pop();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    ref.listen(chatProvider, (_, next) {
      if (next.messages.isNotEmpty || next.isTyping) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Hex grid
          Positioned.fill(
            child: CustomPaint(painter: HexGridPainter()),
          ),
          // Scan line
          const Positioned.fill(child: ScanLineWidget()),
          // Content
          Column(
            children: [
              _buildAppBar(state.activeProvider),
              Expanded(child: _buildMessages(state)),
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

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
            const ArcReactorWidget(size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'F.R.I.D.A.Y.',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00d4ff),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
            // Provider pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildMessages(ChatState state) {
    if (state.messages.isEmpty && !state.isTyping) {
      return _emptyState();
    }

    final itemCount =
        state.messages.length + (state.isTyping ? 1 : 0);

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
          const ArcReactorWidget(size: 72),
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
          Text(
            'Type "help" to see commands',
            style: GoogleFonts.rajdhani(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
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
                style: GoogleFonts.rajdhani(
                    color: Colors.white, fontSize: 16),
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
                    borderSide: const BorderSide(
                        color: Color(0xFF00d4ff), width: 1.5),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 10),
            // Send button with pulse animation
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
                        spreadRadius: 0,
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
    );
  }
}
