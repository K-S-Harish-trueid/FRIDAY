import 'package:flutter/material.dart';

class ScanLineWidget extends StatefulWidget {
  const ScanLineWidget({super.key});

  @override
  State<ScanLineWidget> createState() => _ScanLineWidgetState();
}

class _ScanLineWidgetState extends State<ScanLineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => IgnorePointer(
        child: CustomPaint(
          painter: _ScanLinePainter(progress: _ctrl.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final rect = Rect.fromLTWH(0, y - 40, size.width, 80);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF00d4ff).withValues(alpha: 0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
