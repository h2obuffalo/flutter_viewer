import 'package:flutter/material.dart';

// Glitch text effect widget
// TODO: Implement animated glitch text

class GlitchText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  
  const GlitchText({
    required this.text,
    this.style,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}
