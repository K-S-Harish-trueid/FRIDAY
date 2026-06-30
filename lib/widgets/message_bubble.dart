import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _avatar('F', const Color(0xFF00d4ff), Colors.black),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: isUser ? _userDecoration() : _fridayDecoration(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser && message.isCommand)
                        const Padding(
                          padding: EdgeInsets.only(right: 5, top: 1),
                          child: Text('⚡',
                              style: TextStyle(fontSize: 12)),
                        ),
                      Flexible(
                        child: Text(
                          message.content,
                          style: GoogleFonts.rajdhani(
                            fontSize: 15,
                            color: isUser
                                ? Colors.black.withValues(alpha: 0.88)
                                : const Color(0xFFddeeff),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _ts(message.timestamp),
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.28)),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _avatar('H', const Color(0xFF1a4a6b), const Color(0xFF00d4ff)),
          ],
        ],
      ),
    )
        .animate()
        .slideX(
          begin: isUser ? 0.25 : -0.25,
          end: 0,
          duration: 280.ms,
          curve: Curves.easeOut,
        )
        .fadeIn(duration: 280.ms);
  }

  BoxDecoration _userDecoration() => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00d4ff), Color(0xFF1a4a6b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      );

  BoxDecoration _fridayDecoration() => const BoxDecoration(
        color: Color(0xFF0f2035),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          left: BorderSide(color: Color(0xFF00d4ff), width: 2),
        ),
      );

  Widget _avatar(String letter, Color bg, Color fg) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.45), width: 1),
      ),
      child: Center(
        child: Text(letter,
            style: TextStyle(
                color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
