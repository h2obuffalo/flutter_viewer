import 'package:flutter/material.dart';

// Retro-styled button widget
// TODO: Implement custom button with retro styling

class RetroButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  
  const RetroButton({
    required this.text,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}
