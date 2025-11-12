import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/theme.dart';
import '../services/now_playing_service.dart';
import '../services/remote_lineup_sync_service.dart';
import '../services/notification_service.dart';
import '../widgets/bangface_popup.dart';
import '../widgets/ticket_input_dialog.dart';
import '../services/auth_service.dart';
import '../services/craic_audio_service.dart';
import 'lineup_list_screen.dart';
import 'simple_player_screen.dart';
import 'updates_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  late AnimationController _strobeController;
  late AnimationController _screenGlitchController;
  late AnimationController _raveButtonController;
  late CraicAudioService _raveAudioService;
  bool _isRaveMode = false;
  int _unseenUpdatesCount = 0;
  Timer? _updatesCheckTimer;
  bool? _isSmallScreen; // Cache device detection result
  String? _currentTrackName;
  String? _currentArtistName;
  bool _showTrackInfo = false;

  @override
  void initState() {
    super.initState();
    
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

    _raveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    // Initialize audio service
    _raveAudioService = CraicAudioService();

    // Detect device type for text sizing
    _detectDeviceType();
    
    // Start periodic lineup change checks
    _startLineupChangeChecker();
    
    // Check for unseen updates
    _checkUnseenUpdates();
    _startUpdatesChecker();
  }
  
  Future<void> _detectDeviceType() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      // Try iOS first - device_info_plus will throw if not iOS
      try {
        final iosInfo = await deviceInfo.iosInfo;
        // iPhone 8 has model identifier iPhone10,1 or iPhone10,4
        // iPhone SE (1st gen) and iPhone 7 also have small screens
        final isIPhone8 =
            iosInfo.model == 'iPhone10,1' || iosInfo.model == 'iPhone10,4';
        final isSmallIPhone = iosInfo.model.contains('iPhone') && 
                             (isIPhone8 || 
                              iosInfo.model.contains('iPhone8,') || // iPhone SE, 7, 6s
                              iosInfo.model.contains('iPhone9,') || // iPhone 7, 8
                (double.tryParse(iosInfo.systemVersion.split('.').first) ??
                        13) <
                    13); // Older iPhones
        
        if (mounted) {
          setState(() {
            _isSmallScreen = isSmallIPhone;
          });
        }
        return;
      } catch (e) {
        // Not iOS, continue to check Android or use fallback
      }
      
      // For Android or other platforms, screen size will be checked in build method
    } catch (e) {
      // Fallback will use screen size detection in build method
      if (mounted) {
        // Error getting device info, use screen size fallback
      }
    }
  }
  
  void _startUpdatesChecker() {
    // Check for unseen updates every 30 seconds
    _updatesCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
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

  void _onLiveStreamPressed() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    if (!mounted) return;
    
    // Check if user already has valid token
    final authService = AuthService();
    final hasValidToken = await authService.isTokenValid();
    
    if (hasValidToken) {
      // User already authenticated, go directly to player
      Navigator.pushReplacementNamed(context, '/player');
    } else {
      // Show ticket input dialog
      showDialog(
        context: context,
        barrierDismissible: true, // Allow dismissing by tapping outside
        builder: (context) => const TicketInputDialog(),
      );
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
    print('=== WHATS THE CRAIC BUTTON PRESSED (NO AUDIO) ===');
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Button animation
    await _buttonController.forward();
    await _buttonController.reverse();
    
    if (!mounted) return;
    
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
      // No scheduled content - check authentication first
      final authService = AuthService();
      final hasValidToken = await authService.isTokenValid();
      
      if (!hasValidToken) {
        // Show ticket input dialog first
        final authResult = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => const TicketInputDialog(),
        );
        
        // If user cancelled or dismissed, don't proceed
        if (!mounted || authResult != true) {
          return;
        }
        
        // Re-check authentication after dialog
        final stillNotAuthenticated = !(await authService.isTokenValid());
        if (stillNotAuthenticated) {
          // User didn't authenticate successfully, don't proceed
          return;
        }
      }
      
      // User is authenticated (or was already authenticated), proceed to player
      if (mounted) {
        // Navigate to video player
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

  Timer? _raveModeTimer;

  void _onRaveButtonPressed() async {
    print('=== RAVE BUTTON PRESSED (WITH AUDIO) ===');
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // If rave mode is already active, stop it early
    if (_isRaveMode) {
      _stopRaveMode();
      return;
    }
    
    // Reload tracks first to get any new uploads, then get track info
    _raveAudioService.reloadTracks().then((_) {
      // Get track info AFTER reloading (so we show the correct track name)
      final trackName = _raveAudioService.currentTrackName;
      final artistName = _raveAudioService.currentArtistName;
      
      // Update state to show track info and start rave mode
      if (mounted) {
        setState(() {
          _currentTrackName = trackName;
          _currentArtistName = artistName;
          _showTrackInfo = true;
          _isRaveMode = true;
        });
      }
      
      // Start everything simultaneously
      _raveButtonController.forward(); // Start 6-second animation
      _strobeController.repeat(); // Start the rave mode strobe effects
      _screenGlitchController.repeat(); // Start screen glitch effects
      
      // Start playing the track (don't await - let it start in parallel)
      _raveAudioService.playNextTrack(); // Fire and forget - starts immediately
    });
    
    // Set up timer to stop after 6 seconds
    _raveModeTimer?.cancel();
    _raveModeTimer = Timer(const Duration(seconds: 6), () {
      _stopRaveMode();
    });
  }

  void _stopRaveMode() {
    // Cancel the timer
    _raveModeTimer?.cancel();
    _raveModeTimer = null;
    
    // Stop audio
    _raveAudioService.stop();
    
    // Stop animations and reset state
        if (mounted) {
          setState(() {
            _isRaveMode = false;
        _showTrackInfo = false;
      });
      _strobeController.stop();
      _screenGlitchController.stop();
      _raveButtonController.reset();
    }
  }

  @override
  void dispose() {
    _updatesCheckTimer?.cancel();
    _raveModeTimer?.cancel();
    _pulseController.dispose();
    _buttonController.dispose();
    _strobeController.dispose();
    _screenGlitchController.dispose();
    _raveButtonController.dispose();
    _raveAudioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Determine if this is a small screen device
    // Check cached value first, then fallback to screen size detection
    final isSmallScreen =
        _isSmallScreen ?? (screenHeight < 700 || screenWidth < 400);
    
    // Adjust font sizes for smaller screens like iPhone 8
    final logoHeight = isSmallScreen ? 140.0 : 220.0;
    final verticalSpacing =
        isSmallScreen ? 30.0 : 60.0; // Reduced spacing for small screens
    final buttonSpacing =
        isSmallScreen ? 20.0 : 40.0; // Reduced spacing for small screens
    
    return Scaffold(
      backgroundColor: _isRaveMode ? _getStrobeColor() : RetroTheme.darkBlue,
      body: Stack(
        children: [
          // CRT Scanlines effect
          _buildScanlines(),
          
          // Rave mode screen glitch overlay
          if (_isRaveMode) _buildScreenGlitchOverlay(),
          
          // Main content
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 24.0 : 40.0,
                        vertical: isSmallScreen ? 32.0 : 48.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                // Title with beta stamp
                          Semantics(
                            label: 'Bang Face TV 2025 logo',
                            child: Image.asset(
                              'assets/images/bftv_eye.png',
                              height: logoHeight,
                              fit: BoxFit.contain,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                                  ),
                ),
                SizedBox(height: verticalSpacing),
                
                // Menu buttons
                          _buildMenuButton('BANGFACETV STREAM',
                              _onLiveStreamPressed, RetroTheme.neonCyan),
                const SizedBox(height: 20),
                          _buildMenuButton(
                              'LINEUP', _onLineupPressed, RetroTheme.hotPink),
                const SizedBox(height: 20),
                          _buildMenuButton(
                              'WHAT\'S THE CRAIC',
                              _onWhatsTheCrackPressed,
                              RetroTheme.electricGreen),
                
                SizedBox(height: buttonSpacing),
                
                // Interactive Rave button
                _buildRaveButton(),
              ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Track info overlay at bottom
          if (_showTrackInfo &&
              _currentTrackName != null &&
              _currentArtistName != null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildTrackInfoOverlay(),
            ),
          
          // Bell icon in top-right corner
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _buildUpdatesBellIcon(),
          ),
          
          // Settings cog icon in top-left corner
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _buildSettingsCogIcon(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUpdatesBellIcon() {
    final hasUnseen = _unseenUpdatesCount > 0;
    final iconColor =
        hasUnseen ? RetroTheme.warningYellow : RetroTheme.neonCyan;
    
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
        margin: const EdgeInsets.all(4),
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
                    _unseenUpdatesCount > 99
                        ? '99+'
                        : _unseenUpdatesCount.toString(),
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

  Widget _buildSettingsCogIcon() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        // Preload notification state before navigating to avoid animation jump
        await NotificationService().areNotificationsEnabled();
        if (mounted) {
          Navigator.pushNamed(context, '/settings');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(4),
        child: Icon(
          Icons.settings,
          color: RetroTheme.neonCyan,
          size: 24,
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

  Widget _buildMenuButton(String text, VoidCallback onPressed, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _buttonController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 +
                  (_pulseController.value * 0.05) +
                  (_buttonController.value * 0.1),
              child: GestureDetector(
                onTap: onPressed,
                child: Container(
                  width: 280,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
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

  Widget _buildTrackInfoOverlay() {
    return Center(
      child: Text(
        '$_currentTrackName - $_currentArtistName',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRaveButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _raveButtonController,
          builder: (context, child) {
            final baseColor =
                _isRaveMode ? _getStrobeColor() : Colors.redAccent;
            return Transform.scale(
              scale: 1.0 +
                  (_pulseController.value * 0.1) +
                  (_raveButtonController.value * 0.1),
              child: GestureDetector(
                onTap: _onRaveButtonPressed,
                child: Semantics(
                  button: true,
                  label: _isRaveMode
                      ? 'Raving button active'
                      : 'Ready to Rave button',
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: baseColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: baseColor.withValues(
                              alpha: _isRaveMode ? 0.9 : 0.5),
                        blurRadius: _isRaveMode ? 30 : 15,
                        spreadRadius: _isRaveMode ? 5 : 2,
                      ),
                    ],
                      borderRadius: BorderRadius.circular(10),
                  ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                  child: AnimatedBuilder(
                    animation: _strobeController,
                    builder: (context, child) {
                        final textColor =
                            _isRaveMode ? _getStrobeColor() : baseColor;
                        return Text(
                          _isRaveMode ? 'RAVING!' : 'READY TO RAVE',
                          style: TextStyle(
                            fontSize: 20,
                            color: textColor,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.bold,
                            shadows: _isRaveMode
                                ? [
                              Shadow(
                                      color: textColor,
                                      blurRadius: 12,
                              ),
                                  ]
                                : null,
                        ),
                      );
                    },
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
    
    final index =
        (_strobeController.value * colors.length).floor() % colors.length;
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
