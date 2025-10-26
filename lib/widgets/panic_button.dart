import 'package:flutter/material.dart';

// Panic Button - Refreshes stream and clears cache
// TODO: Implement panic button with retro styling

class PanicButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const PanicButton({
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: const Text('PANIC BUTTON'),
    );
  }
}
