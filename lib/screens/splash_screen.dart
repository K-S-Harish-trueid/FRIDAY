import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringsCtrl;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();

    _ringsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const ChatScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ringsCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = 'F.R.I.D.A.Y.';

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Expanding rings
            AnimatedBuilder(
              animation: _ringsCtrl,
              builder: (_, _) => CustomPaint(
                size: const Size(200, 200),
                painter: _SplashReactorPainter(
                    progress: CurvedAnimation(
                            parent: _ringsCtrl, curve: Curves.easeOut)
                        .value),
              ),
            ),
            const SizedBox(height: 44),

            // Title letter-by-letter
            Row(
              mainAxisSize: MainAxisSize.min,
              children: title.split('').asMap().entries.map((e) {
                return Text(
                  e.value,
                  style: GoogleFonts.orbitron(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF00d4ff),
                    letterSpacing: 1,
                  ),
                )
                    .animate(delay: Duration(milliseconds: 700 + e.key * 90))
                    .fadeIn(duration: 250.ms)
                    .slideY(
                      begin: 0.6,
                      end: 0,
                      duration: 250.ms,
                      curve: Curves.easeOut,
                    );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Blinking subtitle
            AnimatedBuilder(
              animation: _blinkCtrl,
              builder: (_, _) => Opacity(
                opacity: _blinkCtrl.value,
                child: Text(
                  'INITIALIZING SYSTEMS...',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    color: const Color(0xFF00d4ff).withValues(alpha: 0.65),
                    letterSpacing: 4,
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

class _SplashReactorPainter extends CustomPainter {
  final double progress;
  _SplashReactorPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radii = [90.0, 72.0, 54.0, 36.0, 18.0];
    final delays = [0.0, 0.12, 0.24, 0.36, 0.50];

    for (int i = 0; i < radii.length; i++) {
      final t = ((progress - delays[i]) / (1.0 - delays[i])).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final currentR = radii[i] * t;
      final alpha = i == radii.length - 1
          ? t
          : (1.0 - ((t - 0.6) / 0.4).clamp(0.0, 1.0));

      canvas.drawCircle(
        center,
        currentR,
        Paint()
          ..color = const Color(0xFF00d4ff).withValues(alpha: alpha * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + (radii.length - i) * 0.25,
      );
    }

    // Bright core when rings finish
    if (progress > 0.78) {
      final fade = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = const Color(0xFF00d4ff).withValues(alpha: fade * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        center,
        6,
        Paint()..color = Colors.white.withValues(alpha: fade),
      );

      // Three triangles
      final triPaint = Paint()
        ..color = const Color(0xFF00d4ff).withValues(alpha: fade * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (int i = 0; i < 3; i++) {
        final angle = (i * 120) * pi / 180;
        final cx = center.dx, cy = center.dy;
        canvas.drawPath(
          Path()
            ..moveTo(cx + 6 * cos(angle), cy + 6 * sin(angle))
            ..lineTo(cx + 34 * cos(angle - pi / 7),
                cy + 34 * sin(angle - pi / 7))
            ..lineTo(cx + 34 * cos(angle + pi / 7),
                cy + 34 * sin(angle + pi / 7))
            ..close(),
          triPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SplashReactorPainter old) => old.progress != progress;
}
