import 'dart:math';
import 'package:flutter/material.dart';

class HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const hexR = 28.0;
    final hexH = hexR * 2;
    final hexW = hexR * sqrt(3);

    var row = 0;
    for (double y = -hexR; y < size.height + hexH; y += hexH * 0.75) {
      final xOffset = row.isOdd ? hexW / 2 : 0.0;
      for (double x = -hexW + xOffset; x < size.width + hexW; x += hexW) {
        _drawHex(canvas, paint, Offset(x, y), hexR);
      }
      row++;
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * pi / 180;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HexGridPainter _) => false;
}
