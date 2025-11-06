import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<String> _displayLines = [];
  int _currentLineIndex = 0;
  bool _showWarning = false;
  bool _showAllYourBangFace = false;
  bool _isAlternativeMode = false;

  List<String> _bootLogLines = [];
  String _headerText = '';
  String _footerText = '';
  Duration _stage1Duration = const Duration(seconds: 3);
  Duration _totalDuration = const Duration(seconds: 6);
  Timer? _scrollTimer;
  Timer? _stage2Timer;
  Timer? _stage3Timer;
  Timer? _navigationTimer;
  static const int _maxVisibleLines = 30; // Number of lines to show at once
  
  // Touch interaction state
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  DateTime? _stage2StartTime;
  DateTime? _stage3StartTime;
  DateTime? _navigationStartTime;
  Duration _remainingStage1Time = Duration.zero;
  Duration _remainingTotalTime = Duration.zero;
  final ScrollController _scrollController = ScrollController();
  double _manualScrollOffset = 0.0;
  bool _isFirstBoot = false;

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

    _loadBootLog();
  }

  Future<void> _loadBootLog() async {
    try {
      final String jsonData = await rootBundle.loadString('assets/docs/bootloader-log.json');
      final Map<String, dynamic> data = json.decode(jsonData);
      
      setState(() {
        _bootLogLines = List<String>.from(data['bootLogLines'] ?? []);
        _headerText = data['headerText'] ?? '';
        _footerText = data['footerText'] ?? '';
      });
      
      await _calculateDurations();
      _startSplashSequence();
    } catch (e) {
      // Fallback if file can't be loaded
      setState(() {
        _bootLogLines = ['Loading system modules...', '[████████████████████] 100%', '✓ Complete', 'System ready'];
        _headerText = '> ACCESSING BOOTLOADER LOG...\n> DECRYPTING SYSTEM INITIALIZATION...\n\n';
        _footerText = '\n> BOOT SEQUENCE: COMPLETE\n> SYSTEM STATUS: ONLINE';
      });
      
      await _calculateDurations();
      _startSplashSequence();
    }
  }

  Future<void> _calculateDurations() async {
    final prefs = await SharedPreferences.getInstance();
    final hasBootedBefore = prefs.getBool('has_booted_before') ?? false;
    final isFirstBoot = !hasBootedBefore;
    
    setState(() {
      _isFirstBoot = isFirstBoot;
    });
    
    // Fixed durations: 20s first boot, 10s subsequent boots
    final stage1Duration = isFirstBoot 
        ? const Duration(seconds: 20)
        : const Duration(seconds: 10);
    
    // Total duration = Stage 1 + 1 second warning + 1 second final
    final totalDuration = stage1Duration + const Duration(seconds: 2);
    
    setState(() {
      _stage1Duration = stage1Duration;
      _totalDuration = totalDuration;
    });
    
    // Mark that we've booted before
    if (isFirstBoot) {
      await prefs.setBool('has_booted_before', true);
    }
  }

  void _startSplashSequence() {
    // Stage 1: Green CRT terminal with bootloader log
    _startStage1();
    
    _remainingStage1Time = _stage1Duration;
    _remainingTotalTime = _totalDuration;
    
    // Stage 2: Red warning overlay (after Stage 1)
    _scheduleStage2();
    
    // Stage 3: All Your BangFace (1 second after warning)
    _scheduleStage3();
    
    // Navigate to main app
    _scheduleNavigation();
  }
  
  void _scheduleStage2() {
    _stage2Timer?.cancel();
    _stage2StartTime = DateTime.now();
    _stage2Timer = Timer(_remainingStage1Time, () {
      if (mounted && !_isPaused) {
        _startStage2();
      }
    });
  }
  
  void _scheduleStage3() {
    _stage3Timer?.cancel();
    _stage3StartTime = DateTime.now();
    _stage3Timer = Timer(_remainingStage1Time + const Duration(seconds: 1), () {
      if (mounted && !_isPaused) {
        _startStage3();
      }
    });
  }
  
  void _scheduleNavigation() {
    _navigationTimer?.cancel();
    _navigationStartTime = DateTime.now();
    _navigationTimer = Timer(_remainingTotalTime, () {
      if (mounted && !_isPaused) {
        _navigateToMainApp();
      }
    });
  }

  void _startStage1() {
    setState(() {
      _currentStage = 1;
      _displayLines = [];
      _currentLineIndex = 0;
      // Add header text if available
      if (_headerText.isNotEmpty) {
        _displayLines.addAll(_headerText.split('\n').where((line) => line.isNotEmpty));
      }
    });
    
    _typeBootLogLines();
  }

  void _typeBootLogLines() {
    _scrollTimer = Timer(const Duration(milliseconds: 72), () {
      if (mounted && _currentStage == 1 && _bootLogLines.isNotEmpty && !_isPaused) {
        setState(() {
          // Add the current line from boot log
          _displayLines.add(_bootLogLines[_currentLineIndex]);
          
          // Keep only the last _maxVisibleLines visible
          if (_displayLines.length > _maxVisibleLines) {
            _displayLines.removeAt(0);
          }
          
          // Move to next line (stop when reaching end, don't loop)
          if (_currentLineIndex < _bootLogLines.length - 1) {
            _currentLineIndex++;
          } else {
            // Reached the end, stop scrolling
            return;
          }
          
          // Auto-scroll to bottom when not manually scrolling
          if (_scrollController.hasClients && _manualScrollOffset == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients && !_isPaused) {
                _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
              }
            });
          }
        });
        
        // Continue scrolling if we haven't reached the end
        if (_currentLineIndex < _bootLogLines.length) {
          _typeBootLogLines();
        }
      } else if (mounted && _currentStage == 1 && _isPaused) {
        // If paused, check again after a short delay
        _typeBootLogLines();
      }
    });
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

  void _navigateToMainApp() async {
    // Always navigate to main menu first
    // Ticket authentication will be required when watching the stream
    if (!mounted) return;
    
    Navigator.of(context).pushReplacementNamed('/menu');
  }

  void _onPanStart(DragStartDetails details) {
    if (_currentStage == 1) {
      _pauseAnimation();
    }
  }
  
  void _onPanEnd(DragEndDetails details) {
    if (_currentStage == 1 && _isPaused) {
      _resumeAnimation();
    }
  }
  
  void _pauseAnimation() {
    if (!_isPaused && _currentStage == 1) {
      setState(() {
        _isPaused = true;
        _pauseStartTime = DateTime.now();
      });
      
      // Cancel all timers and calculate remaining time
      if (_stage2Timer != null && _stage2Timer!.isActive && _stage2StartTime != null) {
        final elapsed = DateTime.now().difference(_stage2StartTime!);
        _remainingStage1Time = _remainingStage1Time - elapsed;
        if (_remainingStage1Time.isNegative) {
          _remainingStage1Time = Duration.zero;
        }
        _stage2Timer?.cancel();
      }
      
      if (_stage3Timer != null && _stage3Timer!.isActive && _stage3StartTime != null) {
        _stage3Timer?.cancel();
      }
      
      if (_navigationTimer != null && _navigationTimer!.isActive && _navigationStartTime != null) {
        final elapsed = DateTime.now().difference(_navigationStartTime!);
        _remainingTotalTime = _remainingTotalTime - elapsed;
        if (_remainingTotalTime.isNegative) {
          _remainingTotalTime = Duration.zero;
        }
        _navigationTimer?.cancel();
      }
    }
  }
  
  void _resumeAnimation() {
    if (_isPaused && _currentStage == 1 && _pauseStartTime != null) {
      // Calculate how long we were paused and adjust remaining time
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      
      setState(() {
        _isPaused = false;
        _pauseStartTime = null;
        _manualScrollOffset = 0.0;
      });
      
      // Resume timers with remaining time (pause duration doesn't affect remaining time)
      _scheduleStage2();
      _scheduleStage3();
      _scheduleNavigation();
      
      // Resume scrolling if timer was canceled
      if (_scrollTimer == null || !_scrollTimer!.isActive) {
        _typeBootLogLines();
      }
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _stage2Timer?.cancel();
    _stage3Timer?.cancel();
    _navigationTimer?.cancel();
    _scrollController.dispose();
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
          onPanStart: _onPanStart,
          onPanEnd: _onPanEnd,
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
              
              // ABORT button on subsequent boots during stage 1
              if (_currentStage == 1 && !_isFirstBoot)
                _buildExitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCRTTerminal() {
    // Convert display lines list to text string
    final displayText = _displayLines.join('\n');
    
    // Calculate approximate height based on line count and font size
    const double lineHeight = 18.0; // Approximate line height for 14px font
    final double textHeight = _displayLines.length * lineHeight + 64; // Add padding
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            physics: _isPaused ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: textHeight > constraints.maxHeight ? textHeight : constraints.maxHeight,
              child: CRTTerminal(
                text: displayText,
                fontSize: 14.0,
                textColor: const Color(0xFF00FF00),
                showScanlines: true,
                showFlicker: true,
                showGlow: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExitButton() {
    return Positioned(
      right: 24.0,
      bottom: 24.0,
      child: GestureDetector(
        onTap: () {
          // Cancel all timers
          _scrollTimer?.cancel();
          _stage2Timer?.cancel();
          _stage3Timer?.cancel();
          _navigationTimer?.cancel();
          // Skip to next animation stage (Stage 2 - warning)
          _startStage2();
          // Schedule Stage 3 (1 second after Stage 2)
          _stage3Timer = Timer(const Duration(seconds: 1), () {
            if (mounted) {
              _startStage3();
            }
          });
          // Schedule navigation (2 seconds after Stage 2: 1s Stage 2 + 1s Stage 3)
          _navigationTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _navigateToMainApp();
            }
          });
        },
        child: SizedBox(
          width: 120.0,
          height: 60.0,
          child: CRTTerminal(
            text: 'ABORT',
            fontSize: 24.0,
            textColor: const Color(0xFF00FF00),
            showScanlines: true,
            showFlicker: true,
            showGlow: true,
          ),
        ),
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
