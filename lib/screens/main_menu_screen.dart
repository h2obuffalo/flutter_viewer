import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../widgets/glitch_text.dart';
import '../services/now_playing_service.dart';
import '../services/remote_lineup_sync_service.dart';
import '../services/notification_service.dart';
import '../widgets/bangface_popup.dart';
import 'lineup_list_screen.dart';
import 'simple_player_screen.dart';
import 'updates_screen.dart';

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
  int _unseenUpdatesCount = 0;
  Timer? _updatesCheckTimer;

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
    
    // Start periodic lineup change checks
    _startLineupChangeChecker();
    
    // Check for unseen updates
    _checkUnseenUpdates();
    _startUpdatesChecker();
  }
  
  void _startUpdatesChecker() {
    // Check for unseen updates every 30 seconds
    _updatesCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkUnseenUpdates();
    });
  }
  
  Future<void> _checkUnseenUpdates() async {
    try {
      final count = await NotificationService().getUnseenUpdatesCount();
      if (mounted) {
        setState(() {
          _unseenUpdatesCount = count;
        });
      }
    } catch (e) {
      print('Error checking unseen updates: $e');
    }
  }

  void _startLineupChangeChecker() {
    // Check for lineup changes every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final changed = await RemoteLineupSyncService().refreshIfChanged();
        if (changed && mounted) {
          // Notification will be shown automatically by RemoteLineupSyncService
          // Optionally show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lineup updated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error checking lineup changes: $e');
      }
    });
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

  void _onUpdatesPressed() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    // Navigate to updates
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UpdatesScreen()),
      );
    }
  }

  void _onWhatsTheCrackPressed() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    if (mounted) {
      // Load artists and check if there's scheduled content
      await NowPlayingService.loadArtists();
      
      if (NowPlayingService.hasScheduledContent()) {
        // Show lineup with now playing filter
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LineupListScreen(showNowPlaying: true),
          ),
        );
      } else {
        // Show video player with popup
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SimplePlayerScreen(),
          ),
        );
        
        // Show popup after a short delay to ensure player is loaded
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            BangFacePopup.showBangFaceTVPopup(context);
          }
        });
      }
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
    _updatesCheckTimer?.cancel();
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
          
          // Bell icon in top-right corner
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _buildUpdatesBellIcon(),
          ),
          
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
  
  Widget _buildUpdatesBellIcon() {
    final hasUnseen = _unseenUpdatesCount > 0;
    final iconColor = hasUnseen ? RetroTheme.warningYellow : RetroTheme.neonCyan;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _onUpdatesPressed();
        // Refresh unseen count after navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkUnseenUpdates();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RetroTheme.darkBlue.withValues(alpha: 0.8),
          border: Border.all(
            color: iconColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: hasUnseen ? [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications,
              color: iconColor,
              size: 24,
            ),
            if (hasUnseen)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: RetroTheme.warningYellow,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RetroTheme.darkBlue,
                      width: 1,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _unseenUpdatesCount > 99 ? '99+' : _unseenUpdatesCount.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
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
                        color: color.withValues(alpha: 0.3),
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
                        color: (_isRaveMode ? _getStrobeColor() : Colors.red).withValues(alpha: 0.8),
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
      ..color = strobeColor.withValues(alpha: 0.3)
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
