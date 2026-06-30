import 'dart:math';
import 'package:flutter/material.dart';

class ArcReactorWidget extends StatefulWidget {
  final double size;
  final bool animate;

  const ArcReactorWidget({super.key, this.size = 40, this.animate = true});

  @override
  State<ArcReactorWidget> createState() => _ArcReactorWidgetState();
}

class _ArcReactorWidgetState extends State<ArcReactorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ArcReactorPainter(glowIntensity: 1.0),
      );
    }
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ArcReactorPainter(glowIntensity: _glow.value),
      ),
    );
  }
}

class _ArcReactorPainter extends CustomPainter {
  final double glowIntensity;
  _ArcReactorPainter({required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = size.width / 2;

    // Outer blur glow
    canvas.drawCircle(
      center,
      r * 0.88,
      Paint()
        ..color = const Color(0xFF00d4ff).withValues(alpha: 0.25 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
    );

    // Outer ring
    canvas.drawCircle(
      center,
      r * 0.88,
      Paint()
        ..color = const Color(0xFF00d4ff).withValues(alpha: 0.85 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Mid ring
    canvas.drawCircle(
      center,
      r * 0.60,
      Paint()
        ..color = const Color(0xFF00d4ff).withValues(alpha: 0.55 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Radial gradient core
    final coreRect = Rect.fromCircle(center: center, radius: r * 0.42);
    canvas.drawCircle(
      center,
      r * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00d4ff).withValues(alpha: glowIntensity),
            const Color(0xFF00d4ff).withValues(alpha: 0.25 * glowIntensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(coreRect),
    );

    // Bright inner dot
    canvas.drawCircle(
      center,
      r * 0.14,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * glowIntensity),
    );

    // Three triangle sections (arc reactor shape)
    final triPaint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.45 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 3; i++) {
      final angle = (i * 120) * pi / 180;
      final tipX = cx + r * 0.14 * cos(angle);
      final tipY = cy + r * 0.14 * sin(angle);
      final lx = cx + r * 0.52 * cos(angle - pi / 7);
      final ly = cy + r * 0.52 * sin(angle - pi / 7);
      final rx = cx + r * 0.52 * cos(angle + pi / 7);
      final ry = cy + r * 0.52 * sin(angle + pi / 7);
      canvas.drawPath(
        Path()
          ..moveTo(tipX, tipY)
          ..lineTo(lx, ly)
          ..lineTo(rx, ry)
          ..close(),
        triPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcReactorPainter old) =>
      old.glowIntensity != glowIntensity;
}
