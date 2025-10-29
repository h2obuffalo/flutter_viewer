import 'package:flutter/material.dart';
import 'dart:math';
import '../config/theme.dart';

class GlitchAnimations {
  static Widget buildGlitchOverlay(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: GlitchPainter(),
      ),
    );
  }
}

class GlitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint()
      ..color = RetroTheme.neonCyan.withValues(alpha: 0.3)
      ..strokeWidth = 2;

    // Random glitch lines
    for (int i = 0; i < 5; i++) {
      final startY = random.nextDouble() * size.height;
      final x1 = random.nextDouble() * size.width;
      final x2 = random.nextDouble() * size.width;
      
      canvas.drawLine(
        Offset(x1, startY),
        Offset(x2, startY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GlitchPainter oldDelegate) => true;
}
