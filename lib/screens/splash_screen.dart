import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../utils/glitch_animations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _glitchController;
  late AnimationController _fadeController;
  bool _showGlitch = false;

  @override
  void initState() {
    super.initState();
    
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Trigger random glitches
    _triggerRandomGlitch();
    
    // Fade in
    _fadeController.forward();
    
    // Navigate after delay
    _navigateToNextScreen();
  }

  void _triggerRandomGlitch() {
    if (!mounted) return;
    
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showGlitch = true;
        });
        Timer(const Duration(milliseconds: 100), () {
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

  void _navigateToNextScreen() {
    Timer(AppConstants.splashScreenDuration, () async {
      if (!mounted) return;
      
      // Check if user is authenticated
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAuth = await authService.isAuthenticated();
      
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          isAuth ? '/menu' : '/login',
        );
      }
    });
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _fadeController.dispose();
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
            child: FadeTransition(
              opacity: _fadeController,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glitchy logo
                  _buildGlitchText('LIVE', RetroTheme.neonCyan),
                  const SizedBox(height: 20),
                  _buildGlitchText('STREAM', RetroTheme.hotPink),
                  
                  const SizedBox(height: 40),
                  
                  // Loading text
                  Container(
                    decoration: RetroTheme.retroBorder,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'INITIALIZING PROTOCOL',
                          style: TextStyle(
                            fontSize: 20,
                            color: RetroTheme.electricGreen,
                            letterSpacing: 2,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _glitchController,
                          builder: (context, child) {
                            return _glitchController.value > 0.5
                                ? const Text('_', style: TextStyle(fontSize: 20))
                                : const Text(' ');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Random glitch overlay
          if (_showGlitch)
            GlitchAnimations.buildGlitchOverlay(context),
        ],
      ),
    );
  }

  Widget _buildScanlines() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: List.generate(
            100,
            (index) => index % 2 == 0
                ? RetroTheme.darkBlue.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildGlitchText(String text, Color color) {
    return Stack(
      children: [
        // Shadow/offset layer
        if (_showGlitch)
          Positioned(
            left: 2,
            top: 2,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.5),
                letterSpacing: 4,
              ),
            ),
          ),
        // Main text
        Text(
          text,
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: color,
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
