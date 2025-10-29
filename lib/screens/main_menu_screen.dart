import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../widgets/glitch_text.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with TickerProviderStateMixin {
  late AnimationController _glitchController;
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  late AnimationController _strobeController;
  late AnimationController _screenGlitchController;
  bool _showGlitch = false;
  bool _isRaveMode = false;

  @override
  void initState() {
    super.initState();
    
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _strobeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _screenGlitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );

    // Trigger random glitches
    _triggerRandomGlitch();
  }

  void _triggerRandomGlitch() {
    if (!mounted) return;
    
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _showGlitch = true;
        });
        
        Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _showGlitch = false;
            });
            _triggerRandomGlitch();
          }
        });
      }
    });
  }

  void _onLiveStreamPressed() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    // Navigate to player
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/player');
    }
  }

  void _onLineupPressed() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    // Navigate to lineup
    if (mounted) {
      Navigator.pushNamed(context, '/lineup');
    }
  }

  void _onWhatsTheCrackPressed() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    // Navigate to now playing (todo)
    if (mounted) {
      // TODO: Implement now playing screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('What\'s The Crack feature coming soon!'),
          backgroundColor: RetroTheme.hotPink,
        ),
      );
    }
  }

  void _onRaveButtonPressed() async {
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    setState(() {
      _isRaveMode = !_isRaveMode;
    });

    if (_isRaveMode) {
      // Start the rave mode
      _strobeController.repeat();
      _screenGlitchController.repeat();
      
      // Stop after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isRaveMode = false;
          });
          _strobeController.stop();
          _screenGlitchController.stop();
        }
      });
    } else {
      _strobeController.stop();
      _screenGlitchController.stop();
    }
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    _strobeController.dispose();
    _screenGlitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isRaveMode ? _getStrobeColor() : RetroTheme.darkBlue,
      body: Stack(
        children: [
          // CRT Scanlines effect
          _buildScanlines(),
          
          // Rave mode screen glitch overlay
          if (_isRaveMode) _buildScreenGlitchOverlay(),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                _buildGlitchText('BANGFACE', Colors.white),
                const SizedBox(height: 10),
                _buildGlitchText('WEEKENDER', Colors.white),
                const SizedBox(height: 5),
                _buildGlitchText('2025', Colors.white),
                const SizedBox(height: 60),
                
                // Menu buttons
                _buildMenuButton('BANGFACETV STREAM', _onLiveStreamPressed, RetroTheme.neonCyan),
                const SizedBox(height: 20),
                _buildMenuButton('LINEUP', _onLineupPressed, RetroTheme.hotPink),
                const SizedBox(height: 20),
                _buildMenuButton('WHAT\'S THE CRAIC', _onWhatsTheCrackPressed, RetroTheme.electricGreen),
                
                const SizedBox(height: 40),
                
                // Interactive Rave button
                _buildRaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanlines() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00000000),
            Color(0x0A00FF00),
            Color(0x00000000),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildGlitchText(String text, Color color) {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        return GlitchText(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 48,
            letterSpacing: 2,
            fontFamily: 'Impact',
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(String text, VoidCallback onPressed, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _buttonController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.05) + (_buttonController.value * 0.1),
              child: GestureDetector(
                onTap: onPressed,
                child: Container(
                  width: 280,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRaveButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _buttonController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1) + (_buttonController.value * 0.1),
              child: GestureDetector(
                onTap: _onRaveButtonPressed,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isRaveMode ? _getStrobeColor() : Colors.red,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRaveMode ? _getStrobeColor() : Colors.red).withOpacity(0.8),
                        blurRadius: _isRaveMode ? 30 : 15,
                        spreadRadius: _isRaveMode ? 5 : 2,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _strobeController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        child: Text(
                          _isRaveMode ? 'RAVING!' : 'READY TO RAVE',
                          style: TextStyle(
                            fontSize: 18,
                            color: _isRaveMode ? _getStrobeColor() : Colors.red,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            shadows: _isRaveMode ? [
                              Shadow(
                                color: _getStrobeColor(),
                                blurRadius: 10,
                              ),
                            ] : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScreenGlitchOverlay() {
    return AnimatedBuilder(
      animation: _screenGlitchController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: CustomPaint(
            painter: ScreenGlitchPainter(
              animationValue: _screenGlitchController.value,
              strobeColor: _getStrobeColor(),
            ),
          ),
        );
      },
    );
  }

  Color _getStrobeColor() {
    final colors = [
      RetroTheme.neonCyan,
      RetroTheme.hotPink,
      RetroTheme.electricGreen,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.yellow,
    ];
    
    final index = (_strobeController.value * colors.length).floor() % colors.length;
    return colors[index];
  }
}

class ScreenGlitchPainter extends CustomPainter {
  final double animationValue;
  final Color strobeColor;

  ScreenGlitchPainter({
    required this.animationValue,
    required this.strobeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strobeColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final random = Random((animationValue * 1000).round());
    
    // Create random glitch lines across the screen
    for (int i = 0; i < 20; i++) {
      final y = random.nextDouble() * size.height;
      final height = random.nextDouble() * 10 + 2;
      final width = random.nextDouble() * size.width * 0.3 + size.width * 0.1;
      final x = random.nextDouble() * (size.width - width);
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, width, height),
        paint,
      );
    }

    // Add some random pixels
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 3 + 1,
        paint,
      );
    }

    // Add some horizontal scan lines
    for (int i = 0; i < 5; i++) {
      final y = random.nextDouble() * size.height;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
