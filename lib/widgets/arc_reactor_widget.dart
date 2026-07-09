import 'dart:math';
import 'package:flutter/material.dart';

class ArcReactorWidget extends StatefulWidget {
  final double size;
  final bool animate;
  final bool listening;

  const ArcReactorWidget({
    super.key,
    this.size = 40,
    this.animate = true,
    this.listening = false,
  });

  @override
  State<ArcReactorWidget> createState() => _ArcReactorWidgetState();
}

class _ArcReactorWidgetState extends State<ArcReactorWidget>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  late AnimationController _rippleCtrl;
  late Animation<double> _ripple;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: _glowDuration,
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ripple = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    if (widget.listening) _rippleCtrl.repeat();
  }

  Duration get _glowDuration =>
      Duration(milliseconds: widget.listening ? 600 : 2000);

  @override
  void didUpdateWidget(ArcReactorWidget old) {
    super.didUpdateWidget(old);
    if (old.listening != widget.listening) {
      _glowCtrl.duration = _glowDuration;
      if (widget.listening) {
        _rippleCtrl.repeat();
      } else {
        _rippleCtrl.stop();
        _rippleCtrl.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate && !widget.listening) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ArcReactorPainter(
          glowIntensity: 1.0,
          rippleProgress: 0,
          listening: false,
        ),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_glow, _ripple]),
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ArcReactorPainter(
          glowIntensity: _glow.value,
          rippleProgress: widget.listening ? _ripple.value : 0.0,
          listening: widget.listening,
        ),
      ),
    );
  }
}

class _ArcReactorPainter extends CustomPainter {
  final double glowIntensity;
  final double rippleProgress;
  final bool listening;

  _ArcReactorPainter({
    required this.glowIntensity,
    required this.rippleProgress,
    required this.listening,
  });

  static const _cyan = Color(0xFF00d4ff);
  static const _green = Color(0xFF00ff88);

  Color get _primary => listening ? _green : _cyan;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = size.width / 2;

    // Ripple ring (only when listening)
    if (rippleProgress > 0) {
      final rippleR = r * (0.88 + rippleProgress * 0.75);
      final rippleAlpha = (1.0 - rippleProgress) * 0.7;
      canvas.drawCircle(
        center,
        rippleR,
        Paint()
          ..color = _green.withValues(alpha: rippleAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Outer blur glow
    canvas.drawCircle(
      center,
      r * 0.88,
      Paint()
        ..color = _primary.withValues(alpha: 0.25 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
    );

    // Outer ring
    canvas.drawCircle(
      center,
      r * 0.88,
      Paint()
        ..color = _primary.withValues(alpha: 0.85 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Mid ring
    canvas.drawCircle(
      center,
      r * 0.60,
      Paint()
        ..color = _primary.withValues(alpha: 0.55 * glowIntensity)
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
            _primary.withValues(alpha: glowIntensity),
            _primary.withValues(alpha: 0.25 * glowIntensity),
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

    // Three triangle sections
    final triPaint = Paint()
      ..color = _primary.withValues(alpha: 0.45 * glowIntensity)
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
      old.glowIntensity != glowIntensity ||
      old.rippleProgress != rippleProgress ||
      old.listening != listening;
}