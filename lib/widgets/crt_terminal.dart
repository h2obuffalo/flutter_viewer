import 'dart:math';
import 'package:flutter/material.dart';

class CRTTerminal extends StatefulWidget {
  final String text;
  final double fontSize;
  final Color textColor;
  final bool showScanlines;
  final bool showFlicker;
  final bool showGlow;

  const CRTTerminal({
    super.key,
    required this.text,
    this.fontSize = 14.0,
    this.textColor = const Color(0xFF00FF00),
    this.showScanlines = true,
    this.showFlicker = true,
    this.showGlow = true,
  });

  @override
  State<CRTTerminal> createState() => _CRTTerminalState();
}

class _CRTTerminalState extends State<CRTTerminal>
    with TickerProviderStateMixin {
  late AnimationController _flickerController;
  late AnimationController _glowController;
  late Animation<double> _flickerAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _flickerController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _flickerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flickerController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    if (widget.showFlicker) {
      _flickerController.repeat(reverse: true);
    }
    
    if (widget.showGlow) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _flickerController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flickerAnimation, _glowAnimation]),
      builder: (context, child) {
        return CustomPaint(
          painter: CRTPainter(
            text: widget.text,
            fontSize: widget.fontSize,
            textColor: widget.textColor,
            flickerValue: _flickerAnimation.value,
            glowValue: _glowAnimation.value,
            showScanlines: widget.showScanlines,
            showFlicker: widget.showFlicker,
            showGlow: widget.showGlow,
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }
}

class CRTPainter extends CustomPainter {
  final String text;
  final double fontSize;
  final Color textColor;
  final double flickerValue;
  final double glowValue;
  final bool showScanlines;
  final bool showFlicker;
  final bool showGlow;

  CRTPainter({
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.flickerValue,
    required this.glowValue,
    required this.showScanlines,
    required this.showFlicker,
    required this.showGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width);

    // Apply flicker effect
    double opacity = 1.0;
    if (showFlicker) {
      opacity = 0.7 + (flickerValue * 0.3);
    }

    // Calculate text position with some top padding
    final textOffset = Offset(16, 32); // Add padding from top and left

    // Draw glow effect
    if (showGlow) {
      paint.color = textColor.withValues(alpha: 0.3 * glowValue);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      textPainter.paint(canvas, textOffset);
    }

    // Draw main text
    paint.color = textColor.withValues(alpha: opacity);
    paint.maskFilter = null;
    textPainter.paint(canvas, textOffset);

    // Draw scanlines
    if (showScanlines) {
      _drawScanlines(canvas, size);
    }

    // Draw VHS tracking lines occasionally
    if (Random().nextDouble() < 0.1) {
      _drawVHSTracking(canvas, size);
    }
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawVHSTracking(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 2.0;

    final random = Random();
    final y = random.nextDouble() * size.height;
    
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TypingText extends StatefulWidget {
  final String text;
  final Duration duration;
  final TextStyle? style;
  final VoidCallback? onComplete;

  const TypingText({
    super.key,
    required this.text,
    this.duration = const Duration(milliseconds: 20),
    this.style,
    this.onComplete,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayText = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    if (_currentIndex < widget.text.length) {
      Future.delayed(widget.duration, () {
        if (mounted) {
          setState(() {
            _displayText += widget.text[_currentIndex];
            _currentIndex++;
          });
          _startTyping();
        }
      });
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style,
    );
  }
}
