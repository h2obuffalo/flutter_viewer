import 'package:flutter/material.dart';

// TV D-pad focus management widget
// TODO: Implement D-pad navigation for TV

class TVFocusable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  
  const TVFocusable({
    required this.child,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: child,
    );
  }
}
