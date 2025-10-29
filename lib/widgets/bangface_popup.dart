import 'package:flutter/material.dart';
import '../config/theme.dart';

class BangFacePopup {
  static void showBangFaceTVPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: RetroTheme.darkBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: RetroTheme.electricGreen, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BangFace TV Icon
                Icon(
                  Icons.tv,
                  color: RetroTheme.hotPink,
                  size: 64,
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'BANGFACE TV',
                  style: TextStyle(
                    color: RetroTheme.electricGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'IS YOUR OYSTER',
                  style: TextStyle(
                    color: RetroTheme.neonCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontFamily: 'Impact',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'No acts right now.\nWatch the TV!!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontFamily: 'Verdana',
                  ),
                ),
                const SizedBox(height: 24),
                
                // Close button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RetroTheme.hotPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    'RAVE ON',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontFamily: 'Impact',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
