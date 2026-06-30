import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _avatar(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0f2035),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: const Border(
              left: BorderSide(color: Color(0xFF00d4ff), width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Container(
                width: 7,
                height: 7,
                margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                decoration: const BoxDecoration(
                  color: Color(0xFF00d4ff),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(
                    begin: 0,
                    end: -7,
                    duration: 550.ms,
                    delay: Duration(milliseconds: i * 160),
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .moveY(
                    begin: -7,
                    end: 0,
                    duration: 550.ms,
                    curve: Curves.easeInOut,
                  );
            }),
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF00d4ff),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text(
          'F',
          style: TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
