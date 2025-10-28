import 'dart:async';
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
  bool _showGlitch = false;

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

  void _onPlayPressed() async {
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

  @override
  void dispose() {
    _glitchController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.darkBlue,
      body: Stack(
        children: [
          // CRT Scanlines effect
          _buildScanlines(),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                _buildGlitchText('LIVE', RetroTheme.neonCyan),
                const SizedBox(height: 10),
                _buildGlitchText('STREAM', RetroTheme.hotPink),
                
                const SizedBox(height: 60),
                
                // Play button
                _buildPlayButton(),
                
                const SizedBox(height: 40),
                
                // Status text
                Container(
                  decoration: RetroTheme.retroBorder,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: const Text(
                    'READY TO CONNECT',
                    style: TextStyle(
                      fontSize: 16,
                      color: RetroTheme.electricGreen,
                      letterSpacing: 1,
                    ),
                  ),
                ),
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
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        );
      },
    );
  }

  Widget _buildPlayButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _buttonController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1) + (_buttonController.value * 0.1),
              child: GestureDetector(
                onTap: _onPlayPressed,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RetroTheme.neonCyan,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RetroTheme.neonCyan.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      size: 60,
                      color: RetroTheme.neonCyan,
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
}
