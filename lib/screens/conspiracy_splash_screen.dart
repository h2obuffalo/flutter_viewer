import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/conspiracy_texts.dart';
import '../widgets/crt_terminal.dart';

class ConspiracySplashScreen extends StatefulWidget {
  const ConspiracySplashScreen({super.key});

  @override
  State<ConspiracySplashScreen> createState() => _ConspiracySplashScreenState();
}

class _ConspiracySplashScreenState extends State<ConspiracySplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _stageController;
  late AnimationController _warningController;
  late AnimationController _glitchController;
  
  int _currentStage = 0;
  String _displayText = '';
  int _currentTheoryIndex = 0;
  bool _showWarning = false;
  bool _showAllYourBangFace = false;
  bool _isAlternativeMode = false;

  final List<String> _theories = ConspiracyTexts.theories;

  @override
  void initState() {
    super.initState();
    
    _stageController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _warningController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _startSplashSequence();
  }

  void _startSplashSequence() {
    // Stage 1: Green CRT terminal (0-3 seconds)
    _startStage1();
    
    // Stage 2: Red warning overlay (3-4 seconds)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _startStage2();
      }
    });
    
    // Stage 3: All Your BangFace (4-6 seconds)
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _startStage3();
      }
    });
    
    // Navigate to main app (6 seconds)
    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        _navigateToMainApp();
      }
    });
  }

  void _startStage1() {
    setState(() {
      _currentStage = 1;
      _displayText = ConspiracyTexts.headerText;
    });
    
    _typeTheories();
  }

  void _typeTheories() {
    if (_currentTheoryIndex < _theories.length) {
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _displayText += '>> "${_theories[_currentTheoryIndex]}"\n';
            _currentTheoryIndex++;
          });
          _typeTheories();
        }
      });
    } else {
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _displayText += ConspiracyTexts.footerText;
          });
        }
      });
    }
  }

  void _startStage2() {
    setState(() {
      _currentStage = 2;
      _showWarning = true;
    });
    
    _warningController.repeat(reverse: true);
  }

  void _startStage3() {
    setState(() {
      _currentStage = 3;
      _showWarning = false;
      _showAllYourBangFace = true;
    });
    
    _warningController.stop();
    _glitchController.repeat();
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacementNamed('/menu');
  }

  void _onTap() {
    if (_currentStage == 1) {
      setState(() {
        _isAlternativeMode = !_isAlternativeMode;
        _currentTheoryIndex = 0;
        _displayText = ConspiracyTexts.headerText;
      });
      _typeTheories();
    }
  }

  @override
  void dispose() {
    _stageController.dispose();
    _warningController.dispose();
    _glitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _onTap,
          child: Stack(
            children: [
              // Stage 1: Green CRT Terminal
              if (_currentStage == 1)
                _buildCRTTerminal(),
              
              // Stage 2: Red Warning Overlay
              if (_currentStage == 2)
                _buildWarningOverlay(),
              
              // Stage 3: All Your BangFace
              if (_currentStage == 3)
                _buildAllYourBangFace(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCRTTerminal() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: CRTTerminal(
        text: _displayText,
        fontSize: 14.0,
        textColor: const Color(0xFF00FF00),
        showScanlines: true,
        showFlicker: true,
        showGlow: true,
      ),
    );
  }

  Widget _buildWarningOverlay() {
    return AnimatedBuilder(
      animation: _warningController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            children: [
              // Green CRT background
              _buildCRTTerminal(),
              
              // Red warning overlay
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.red.withValues(alpha: 0.3 * _warningController.value),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ConspiracyTexts.warningTexts.map((text) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            shadows: [
                              Shadow(
                                color: Colors.red,
                                blurRadius: 10.0,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllYourBangFace() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glitch effect with multiple color layers
                Stack(
                  children: [
                    // Red layer
                    Transform.translate(
                      offset: Offset(2 * _glitchController.value, 0),
                      child: Text(
                        ConspiracyTexts.allYourBangFaceText,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16.0,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Blue layer
                    Transform.translate(
                      offset: Offset(-2 * _glitchController.value, 0),
                      child: Text(
                        ConspiracyTexts.allYourBangFaceText,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16.0,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Green layer (main)
                    Text(
                      ConspiracyTexts.allYourBangFaceText,
                      style: TextStyle(
                        color: const Color(0xFF00FF00),
                        fontSize: 16.0,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00FF00),
                            blurRadius: 10.0,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
