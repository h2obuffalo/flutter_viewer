import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/constants.dart';
import '../widgets/cast_button.dart';
import '../services/cast_service.dart';
import '../services/stream_health_monitor.dart';
import '../services/auth_service.dart';
import '../utils/platform_utils.dart';

// Web interop - conditional imports
// Pattern: default is stub (for mobile), if html library exists (web) use real
import '../utils/web_stub.dart' if (dart.library.html) 'dart:html' as web;
import '../utils/js_util_stub.dart' if (dart.library.html) 'dart:js_util' as js_util;

/// Simple player screen for mobile platforms using video_player
/// with automatic reconnection and lifecycle handling
class SimplePlayerScreen extends StatefulWidget {
  const SimplePlayerScreen({super.key});

  @override
  State<SimplePlayerScreen> createState() => _SimplePlayerScreenState();
}

class _SimplePlayerScreenState extends State<SimplePlayerScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  String? _errorMessage;
  bool _isInitialized = false;
  bool _isReconnecting = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  bool _isInBackground = false;
  Timer? _statusCheckTimer;
  // Removed unused variables: _streamOnline, _statusCheckAttempts, _maxStatusCheckAttempts
  
  // Fullscreen and animation state
  bool _isFullscreen = false;
  late AnimationController _playPauseAnimationController;
  late AnimationController _seekBackAnimationController;
  late AnimationController _seekForwardAnimationController;
  late AnimationController _fullscreenAnimationController;
  
  // Controls visibility state
  bool _showControls = true;
  Timer? _hideControlsTimer;
  
  // Tap zone animation state
  bool _showLeftTapZone = false;
  bool _showRightTapZone = false;
  Timer? _tapZoneTimer;
  
  // Hold rewind state
  bool _isHoldingRewind = false;
  Timer? _rewindTimer;
  
  // Cast service
  final CastService _castService = CastService();
  
  // Cast state
  bool _isCasting = false;
  String? _castDeviceName;
  String? _streamUrl; // Authenticated stream URL (with token)
  
  // Stream health monitoring
  final StreamHealthMonitor _healthMonitor = StreamHealthMonitor();
  bool _isStreamHealthy = true;
  String _healthStatus = 'Stream healthy';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animation controllers
    _playPauseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _seekBackAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _seekForwardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fullscreenAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    // Start in landscape/fullscreen mode (skip on web - let browser handle it)
    if (!kIsWeb) {
      Future.microtask(() async {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        setState(() {
          _isFullscreen = true;
        });
      });
    } else {
      // On web, just set fullscreen state
      setState(() {
        _isFullscreen = true;
      });
    }
    
    _initConnectivityListener();
    _initPlayer();
    
    // Start auto-hide timer for controls
    _startHideControlsTimer();
    
    // Initialize cast service
    _castService.initialize();
    
    // Listen to cast state changes
    _castService.isConnectedStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isCasting = connected;
        });
      }
    });
    
    // Note: For live streaming, local playback continues when casting
    // Both devices play the same live stream independently - no sync needed
    
    _castService.deviceNameStream.listen((deviceName) {
      if (mounted) {
        setState(() {
          _castDeviceName = deviceName;
        });
      }
    });
    
    // Initialize stream health monitor
    _healthMonitor.initialize(
      onDeadStreamDetected: _handleDeadStreamDetected,
      onStreamHealthy: _handleStreamHealthy,
    );
    
    // Listen to health status changes
    _healthMonitor.isHealthyStream.listen((isHealthy) {
      if (mounted) {
        setState(() {
          _isStreamHealthy = isHealthy;
        });
      }
    });
    
    _healthMonitor.healthStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _healthStatus = status;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
    _statusCheckTimer?.cancel();
    _hideControlsTimer?.cancel();
    _tapZoneTimer?.cancel();
    _rewindTimer?.cancel();
    _videoPlayerController?.dispose();
    
    // Dispose cast service
    _castService.dispose();
    
    // Dispose health monitor
    _healthMonitor.dispose();
    
    // Dispose animation controllers
    _playPauseAnimationController.dispose();
    _seekBackAnimationController.dispose();
    _seekForwardAnimationController.dispose();
    _fullscreenAnimationController.dispose();
    
    // Restore portrait mode and system UI (skip on web)
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    
    // Disable wake lock when player is disposed
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isInBackground = true;
      _pausePlayback();
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _resumePlayback();
    }
  }

  Future<void> _initConnectivityListener() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        _connectionStatus = result;
        if (result == ConnectivityResult.none) {
          print('No internet connection');
        } else if (_isInitialized && _errorMessage != null) {
          // Try to reconnect when connection is restored
          _attemptReconnect();
        }
      });
    } catch (e) {
      print('Error setting up connectivity listener: $e');
    }
  }

  Future<void> _initPlayer() async {
    try {
      final authService = AuthService();
      
      // Check if user has valid ticket authentication
      final hasValidToken = await authService.isTokenValid();
      if (!hasValidToken) {
        // Redirect back to menu - user can click stream button to show ticket dialog
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/menu');
        }
        return;
      }
      
      // On web, use JavaScript HLS player instead of video_player
      if (kIsWeb) {
        print('Web platform detected - using JavaScript HLS player');
        await _initWebPlayer();
        return;
      }
      
      final hlsUrl = await authService.getAuthedHlsUrl();
      if (hlsUrl == null) {
        print('❌ No stream URL configured or no valid token');
        setState(() {
          _errorMessage = 'Stream URL not configured. Please contact support.';
          _isInitialized = false;
        });
        return;
      }
      
      // Store authenticated URL for casting
      setState(() {
        _streamUrl = hlsUrl;
      });
      
      print('Initializing video player with URL: ${hlsUrl.substring(0, hlsUrl.length > 50 ? 50 : hlsUrl.length)}...');
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(hlsUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        formatHint: VideoFormat.hls, // Explicitly declare HLS format for better buffering
      );

      // Initialize the controller
      await _videoPlayerController!.initialize();
      
      // Set buffer duration if supported (fallback: native player handles this)
      try {
        // The video_player package will handle buffering natively
        // This is a best-effort to hint at longer buffer
        print('Video player initialized with ${_videoPlayerController!.value.size}');
      } catch (e) {
        print('Could not access player buffer configuration: $e');
      }
      
      // Set up error handling and health monitoring
      _videoPlayerController!.addListener(() {
        final value = _videoPlayerController!.value;
        
        if (value.hasError) {
          print('Video player error: ${value.errorDescription}');
          _errorMessage = value.errorDescription ?? 'Unknown error';
          _healthMonitor.reportError(value.errorDescription ?? 'Unknown error');
          if (!_isReconnecting) {
            _attemptReconnect();
          }
        } else {
          // Report successful playback
          _healthMonitor.reportSuccess();
          
          // For live streams, focus on buffered end changes rather than position
          // Position monitoring is unreliable for live content
          if (value.buffered.isNotEmpty) {
            _healthMonitor.updateBufferedEnd(value.buffered.last.end);
          }
        }
      });

      // Start playing automatically
      await _videoPlayerController!.play();

      setState(() {
        _isInitialized = true;
        _errorMessage = null;
        _reconnectAttempt = 0;
      });

      // Keep screen awake during playback
      await WakelockPlus.enable();
      print('Screen wake lock enabled');
      
      print('Video player initialized successfully');
    } catch (e) {
      print('Error initializing player: $e');
      _handleInitializationError(e);
    }
  }
  
  Future<void> _initWebPlayer() async {
    // First, get the authenticated stream URL
    try {
      final authService = AuthService();
      
      // Check if token is valid
      final isTokenValid = await authService.isTokenValid();
      if (!isTokenValid) {
        print('❌ No valid token found - cannot initialize player');
        setState(() {
          _errorMessage = 'Authentication required. Please enter your ticket number.';
          _isInitialized = false;
        });
        return;
      }
      
      // Get authenticated HLS URL with token
      final authedUrl = await authService.getAuthedHlsUrl();
      if (authedUrl == null) {
        print('❌ No stream URL configured or no valid token');
        setState(() {
          _errorMessage = 'Stream URL not configured. Please contact support.';
          _isInitialized = false;
        });
        return;
      }
      print('✅ Got authenticated stream URL: ${authedUrl.substring(0, authedUrl.length > 50 ? 50 : authedUrl.length)}...');
      
      // Store authenticated URL for casting
      setState(() {
        _streamUrl = authedUrl;
      });
      
      // Call JavaScript to initialize player with authenticated URL
      try {
        // ignore: avoid_web_libraries_in_flutter
        // On web, web.window gives us the window object. On mobile, stub provides it.
        final window = web.window;
        // Call the function directly as a method on window
        if (kIsWeb) {
          js_util.callMethod(window, 'initializeHLSPlayerWithToken', [authedUrl]);
        } else {
          // Should never reach here on mobile (kIsWeb check above)
          throw UnsupportedError('Web player initialization not supported on mobile');
        }
        print('✅ Called JavaScript to initialize HLS player with token');
      } catch (e) {
        print('❌ Error calling JavaScript init function: $e');
        setState(() {
          _errorMessage = 'Failed to initialize player: $e';
        });
        return;
      }
      
      // Wait for JS player to initialize (retry up to 10 times)
      int retries = 0;
      while (retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        final jsPlayer = _getJSPlayer();
        if (jsPlayer != null) {
          print('JavaScript HLS player found, initializing...');
          
          // Show the video element
          _callJSMethod('show', []);
          
          // Try to play
          try {
            _callJSMethod('play', []);
          } catch (e) {
            print('Autoplay may be blocked: $e');
          }
          
          setState(() {
            _isInitialized = true;
            _errorMessage = null;
            _reconnectAttempt = 0;
          });
          
          print('Web HLS player initialized successfully');
          return;
        }
        
        retries++;
        print('Waiting for JS HLS player... (attempt $retries/10)');
      }
      
      // If we get here, player never initialized
      print('JavaScript HLS player not available after retries');
      setState(() {
        _errorMessage = 'HLS player failed to initialize. Token may be invalid or stream offline.';
      });
    } catch (e) {
      print('❌ Error in _initWebPlayer: $e');
      setState(() {
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }
  
  dynamic _getJSPlayer() {
    if (!kIsWeb) return null;
    
    try {
      // Access window.hlsVideoPlayer using js_util for proper JS interop
      // ignore: avoid_web_libraries_in_flutter
      if (!kIsWeb) return null; // Double check
      final window = web.window;
      
      // Try to get the player directly (it might exist even if ready flag isn't set yet)
      final player = js_util.getProperty(window, 'hlsVideoPlayer');
      if (player != null) {
        // Check if it's a valid player object (has video property or methods)
        final hasVideo = js_util.getProperty(player, 'video');
        final hasPlay = js_util.getProperty(player, 'play');
        if (hasVideo != null || hasPlay != null) {
          print('✅ JS player found (has valid player object)');
          return player;
        }
      }
      
      // Also check ready flag for additional confirmation
      final isReady = js_util.getProperty(window, 'hlsPlayerReady');
      if (isReady == true && player != null) {
        print('✅ JS player found and ready flag confirmed');
        return player;
      }
      
      print('⏳ JS player not available (player: ${player != null ? "exists" : "null"}, ready: $isReady)');
    } catch (e) {
      print('Error accessing JS player: $e');
    }
    return null;
  }
  
  void _callJSMethod(String method, List<dynamic> args) {
    if (!kIsWeb) return;
    
    try {
      // Use js_util for proper JS interop to access and call JS methods
      // ignore: avoid_web_libraries_in_flutter
      final window = web.window;
      final player = js_util.getProperty(window, 'hlsVideoPlayer');
      if (player != null) {
        // Call the method directly on the player object
        js_util.callMethod(player, method, args);
        print('✅ Called JS method: $method');
        return;
      }
      print('⚠️ JS player not available (window.hlsVideoPlayer is null)');
    } catch (e) {
      print('❌ Error calling JS method $method: $e');
    }
  }

  void _handleInitializationError(dynamic error) {
    final errorMsg = error.toString();
    
    // Determine if error is fatal or recoverable
    bool isFatal = errorMsg.contains('format not supported') || 
                   errorMsg.contains('invalid') ||
                   errorMsg.contains('not found');
    
    setState(() {
      _errorMessage = isFatal 
          ? 'Stream not available or format not supported'
          : 'Failed to load stream. Will retry...';
    });
    
    if (!isFatal && !_isReconnecting) {
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (_isReconnecting) return;
    
    setState(() {
      _isReconnecting = true;
    });
    
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isReconnecting && _reconnectAttempt < 5) {
      final delay = _calculateBackoffDelay(_reconnectAttempt);
      _reconnectAttempt++;
      
      print('Scheduling reconnect attempt $_reconnectAttempt in ${delay.inSeconds}s');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        _performReconnect();
      });
    } else if (_reconnectAttempt >= 5) {
      // Give up after 5 attempts
      setState(() {
        _isReconnecting = false;
        _errorMessage = 'Unable to connect to stream after multiple attempts';
      });
    }
  }

  Duration _calculateBackoffDelay(int attempt) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (max 30s)
    final delay = Duration(seconds: (1 << attempt).clamp(1, 30));
    return delay;
  }

  Future<void> _performReconnect() async {
    // On web, don't use video_player reconnection - use JS player
    if (kIsWeb) {
      print('Web platform: Retrying JS HLS player initialization...');
      setState(() {
        _isReconnecting = false;
        _isInitialized = false;
        _errorMessage = null;
      });
      await _initWebPlayer();
      return;
    }
    
    try {
      print('Attempting to reconnect with fresh stream URL...');
      
      // Dispose current controller
      _videoPlayerController?.dispose();
      
      // Reset health monitor
      _healthMonitor.reset();
      
      setState(() {
        _isInitialized = false;
        _errorMessage = null;
      });
      
      // Check if user still has valid ticket authentication
      final authService = AuthService();
      final hasValidToken = await authService.isTokenValid();
      if (!hasValidToken) {
        // Redirect back to menu - user can click stream button to show ticket dialog
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/menu');
        }
        return;
      }
      
      // Get fresh authed URL
      final freshUrl = await authService.getAuthedHlsUrl();
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final freshUrlWithCache = freshUrl != null 
          ? '$freshUrl${freshUrl.contains('?') ? '&' : '?'}t=$cacheBuster'
          : null;
      
      if (freshUrlWithCache == null) {
        print('❌ Cannot reconnect: No stream URL available');
        setState(() {
          _errorMessage = 'Stream URL not configured. Cannot reconnect.';
        });
        return;
      }
      
      print('Using fresh stream URL: $freshUrlWithCache');
      
      // Create new controller with fresh URL
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(freshUrlWithCache),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        formatHint: VideoFormat.hls,
      );

      // Initialize the controller
      await _videoPlayerController!.initialize();
      
      // Set up error handling and health monitoring
      _videoPlayerController!.addListener(() {
        final value = _videoPlayerController!.value;
        
        if (value.hasError) {
          print('Video player error: ${value.errorDescription}');
          _errorMessage = value.errorDescription ?? 'Unknown error';
          _healthMonitor.reportError(value.errorDescription ?? 'Unknown error');
          if (!_isReconnecting) {
            _attemptReconnect();
          }
        } else {
          // Report successful playback
          _healthMonitor.reportSuccess();
          
          // For live streams, focus on buffered end changes rather than position
          // Position monitoring is unreliable for live content
          if (value.buffered.isNotEmpty) {
            _healthMonitor.updateBufferedEnd(value.buffered.last.end);
          }
        }
      });

      // Start playing automatically
      await _videoPlayerController!.play();

      setState(() {
        _isInitialized = true;
        _errorMessage = null;
        _reconnectAttempt = 0;
        _isReconnecting = false;
      });

      // Keep screen awake during playback
      await WakelockPlus.enable();
      
      print('Reconnected successfully with fresh stream');
    } catch (e) {
      print('Reconnection failed: $e');
      _scheduleReconnect();
    }
  }

  void _pausePlayback() {
    if (_isInBackground) {
      _videoPlayerController?.pause();
    }
  }

  void _resumePlayback() {
    if (!_isInBackground && !_isReconnecting) {
      _videoPlayerController?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullscreen) {
          // Exit fullscreen first, don't exit app
          _toggleFullscreen();
          return false;
        }
        // In portrait mode, navigate to menu instead of exiting app
        if (!kIsWeb) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/menu');
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isFullscreen ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            // Restore portrait mode (skip on web)
            if (!kIsWeb) {
              await SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
              await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            }
            
            // Return to menu
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/menu');
            }
          },
        ),
        title: Row(
          children: [
            const Text(
              'Bangface STREAM',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 10),
            _buildConnectionIndicator(),
          ],
        ),
      ),
      body: _isReconnecting
          ? _buildReconnectingView()
          : _errorMessage != null
              ? _buildErrorView()
              : _isInitialized && _videoPlayerController != null
                  ? _buildPlayerView()
                  : _buildLoadingView(),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    if (_connectionStatus == ConnectivityResult.none) {
      return const Icon(Icons.signal_wifi_off, color: Colors.red, size: 20);
    } else if (_connectionStatus == ConnectivityResult.mobile) {
      return const Icon(Icons.signal_cellular_alt, color: Colors.orange, size: 20);
    } else {
      return const Icon(Icons.wifi, color: Colors.green, size: 20);
    }
  }

  Widget _buildReconnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/bangface.gif',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Reconnecting...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            'Attempt ${_reconnectAttempt + 1}/5',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/bangface.gif',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading stream...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to Play Stream',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _reconnectAttempt = 0;
                    _attemptReconnect();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitialized = false;
                      _reconnectAttempt = 0;
                    });
                    _initPlayer();
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Reload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView() {
    // On web, the JS HLS player handles video display
    if (kIsWeb) {
      return _buildWebPlayerView();
    }
    
    return GestureDetector(
      onTapDown: _onVideoTap,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            ),
          ),
          
          // Stream health indicator overlay - fades with controls
          Positioned(
            top: 10,
            left: 10,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isStreamHealthy ? Colors.green.withValues(alpha: 0.8) : Colors.orange.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isStreamHealthy ? Icons.check_circle : Icons.warning,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isStreamHealthy ? 'HEALTHY' : 'CHECKING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Casting indicator overlay
          if (_isCasting)
            Positioned(
              top: 50,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cast_connected,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Casting to $_castDeviceName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'VT323',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Fullscreen controls - centered play button with tap zones
          if (_isFullscreen) _buildFullscreenControls(),
          
          // Portrait controls - traditional bottom controls
          if (!_isFullscreen) _buildPortraitControls(),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required AnimationController animationController,
    bool isMainButton = false,
  }) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        final scale = Tween<double>(
          begin: 1.0,
          end: 0.85,
        ).animate(CurvedAnimation(
          parent: animationController,
          curve: Curves.easeInOut,
        ));
        
        final glowIntensity = Tween<double>(
          begin: 0.3,
          end: 0.8,
        ).animate(CurvedAnimation(
          parent: animationController,
          curve: Curves.easeInOut,
        ));
        
        return Transform.scale(
          scale: scale.value,
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              animationController.forward();
            },
            onTapUp: (_) {
              animationController.reverse();
              onPressed();
            },
            onTapCancel: () {
              animationController.reverse();
            },
            child: Container(
              width: isMainButton ? 60 : 50,
              height: isMainButton ? 60 : 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48), // Reduced from 0.6 to 0.48 (20% less opaque)
                shape: BoxShape.circle,
                boxShadow: [], // Remove blue glow
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isMainButton ? 30 : 24,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullscreenControls() {
    return Stack(
      children: [
        // Left tap zone for double-tap rewind and hold rewind
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width / 3,
          child: GestureDetector(
            onDoubleTap: () {
              _seekBackward();
              _showTapZoneAnimation('left');
            },
            onLongPressStart: (_) {
              _startHoldRewind();
            },
            onLongPressEnd: (_) {
              _stopHoldRewind();
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // Right tap zone for double-tap forward
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width / 3,
          child: GestureDetector(
            onDoubleTap: () {
              _seekForward();
              _showTapZoneAnimation('right');
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // Left tap zone overlay animation
        if (_showLeftTapZone)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width / 3,
            child: AnimatedOpacity(
              opacity: 0.9,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.cyan.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.replay_30,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        
        // Right tap zone overlay animation
        if (_showRightTapZone)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width / 3,
            child: AnimatedOpacity(
              opacity: 0.9,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.cyan.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.forward_10,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        
        // Center play/pause button
        Center(
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _videoPlayerController!,
              builder: (context, value, child) {
                return _buildLargePlayButton(
                  icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: () {
                    _togglePlayPause();
                    _showControlsTemporarily();
                  },
                );
              },
            ),
          ),
        ),
        
        // Cast button in bottom right, left of fullscreen exit button
        Positioned(
          bottom: 20,
          right: 80,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: CastButton(
              hlsUrl: _streamUrl ?? '',
              title: 'Live Stream',
            ),
          ),
        ),
        
        // Fullscreen exit button in bottom right
        Positioned(
          bottom: 20,
          right: 20,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _buildControlButton(
              icon: Icons.fullscreen_exit,
              onPressed: () {
                _toggleFullscreen();
                _showControlsTemporarily();
              },
              animationController: _fullscreenAnimationController,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWebPlayerView() {
    // On web, the JavaScript HLS player handles the video display
    // This widget just provides the Flutter UI overlay (controls, etc.)
    // The actual video element is managed by JavaScript in index.html
    return GestureDetector(
      onTapDown: _onVideoTap,
      child: Stack(
        children: [
          // Placeholder/background - video is handled by JS
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Stream health indicator overlay - same as mobile
          Positioned(
            top: 10,
            left: 10,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isStreamHealthy ? Colors.green.withValues(alpha: 0.8) : Colors.orange.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isStreamHealthy ? Icons.check_circle : Icons.warning,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isStreamHealthy ? 'HEALTHY' : 'CHECKING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Casting indicator overlay
          if (_isCasting)
            Positioned(
              top: 50,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cast_connected,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Casting to $_castDeviceName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'VT323',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Controls - simplified for web (no fullscreen toggle needed)
          // Center play/pause button
          Center(
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildLargePlayButton(
                icon: Icons.play_arrow, // TODO: Check JS player state
                onPressed: () {
                  _togglePlayPause();
                  _showControlsTemporarily();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitControls() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Back 30s button
              _buildControlButton(
                icon: Icons.replay_30,
                onPressed: () {
                  _seekBackward();
                  _showControlsTemporarily();
                },
                animationController: _seekBackAnimationController,
              ),
              
              // Play/Pause button - reactive to player state (skip on web)
              if (!kIsWeb)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _videoPlayerController!,
                  builder: (context, value, child) {
                    return _buildControlButton(
                      icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                      onPressed: () {
                        _togglePlayPause();
                        _showControlsTemporarily();
                      },
                      animationController: _playPauseAnimationController,
                      isMainButton: true,
                    );
                  },
                )
              else
                _buildControlButton(
                  icon: Icons.play_arrow, // TODO: Get state from JS player
                  onPressed: () {
                    _togglePlayPause();
                    _showControlsTemporarily();
                  },
                  animationController: _playPauseAnimationController,
                  isMainButton: true,
                ),
              
              // Forward 30s button
              _buildControlButton(
                icon: Icons.forward_30,
                onPressed: () {
                  _seekForward();
                  _showControlsTemporarily();
                },
                animationController: _seekForwardAnimationController,
              ),
              
              // Cast button
              CastButton(
                hlsUrl: _streamUrl ?? '',
                title: 'Live Stream',
              ),
              
              // Fullscreen button (skip on web - browser handles it)
              if (!kIsWeb)
                _buildControlButton(
                  icon: Icons.fullscreen,
                  onPressed: () {
                    _toggleFullscreen();
                    _showControlsTemporarily();
                  },
                  animationController: _fullscreenAnimationController,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargePlayButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _playPauseAnimationController,
      builder: (context, child) {
        final scale = Tween<double>(
          begin: 1.0,
          end: 0.9,
        ).animate(CurvedAnimation(
          parent: _playPauseAnimationController,
          curve: Curves.easeInOut,
        ));
        
        final glowIntensity = Tween<double>(
          begin: 0.3,
          end: 0.8,
        ).animate(CurvedAnimation(
          parent: _playPauseAnimationController,
          curve: Curves.easeInOut,
        ));
        
        return Transform.scale(
          scale: scale.value,
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              _playPauseAnimationController.forward();
            },
            onTapUp: (_) {
              _playPauseAnimationController.reverse();
              onPressed();
            },
            onTapCancel: () {
              _playPauseAnimationController.reverse();
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48), // Reduced from 0.6 to 0.48 (20% less opaque)
                shape: BoxShape.circle,
                boxShadow: [], // Remove blue glow
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        );
      },
    );
  }

  void _togglePlayPause() {
    if (kIsWeb) {
      // On web, control the JS HLS player
      // Check if video is playing and toggle
      try {
        // ignore: avoid_web_libraries_in_flutter
        final window = web.window;
        final player = js_util.getProperty(window, 'hlsVideoPlayer');
        if (player != null) {
          final video = js_util.getProperty(player, 'video');
          if (video != null) {
            final paused = js_util.getProperty(video, 'paused');
            if (paused == true) {
              _callJSMethod('play', []);
            } else {
              _callJSMethod('pause', []);
            }
            setState(() {}); // Trigger rebuild
            return;
          }
        }
      } catch (e) {
        print('Error toggling play/pause: $e');
      }
      // Fallback to just calling play
      _callJSMethod('play', []);
      setState(() {}); // Trigger rebuild
    } else if (_videoPlayerController != null) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
      // Trigger rebuild to update button icon
      setState(() {});
    }
  }

  void _seekBackward() {
    if (_videoPlayerController != null) {
      final currentPosition = _videoPlayerController!.value.position;
      final newPosition = currentPosition - const Duration(seconds: 30);
      _videoPlayerController!.seekTo(newPosition);
    }
  }

  void _seekForward() {
    if (_videoPlayerController != null) {
      final currentPosition = _videoPlayerController!.value.position;
      final newPosition = currentPosition + const Duration(seconds: 10);
      _videoPlayerController!.seekTo(newPosition);
    }
  }

  void _toggleFullscreen() async {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
    
    if (!_isFullscreen) {
      // Enter fullscreen mode (skip on web - use browser fullscreen API)
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      setState(() {
        _isFullscreen = true;
      });
    } else {
      // Exit fullscreen mode (skip on web)
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      setState(() {
        _isFullscreen = false;
      });
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _onVideoTap(TapDownDetails details) {
    // Only show controls on tap - no play/pause toggle
    _showControlsTemporarily();
  }

  void _showTapZoneAnimation(String side) {
    // Cancel any existing timer
    _tapZoneTimer?.cancel();
    
    // Show the appropriate tap zone
    setState(() {
      if (side == 'left') {
        _showLeftTapZone = true;
        _showRightTapZone = false;
      } else {
        _showRightTapZone = true;
        _showLeftTapZone = false;
      }
    });
    
    // Hide the tap zone after 500ms
    _tapZoneTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showLeftTapZone = false;
          _showRightTapZone = false;
        });
      }
    });
  }

  void _startHoldRewind() {
    if (_isHoldingRewind) return;
    
    _isHoldingRewind = true;
    _showTapZoneAnimation('left');
    
    // Start continuous rewind at 2x speed
    _rewindTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isHoldingRewind && _videoPlayerController != null) {
        final currentPosition = _videoPlayerController!.value.position;
        final newPosition = currentPosition - const Duration(seconds: 1); // 2x speed (1 second per 500ms)
        _videoPlayerController!.seekTo(newPosition);
      }
    });
  }

  void _stopHoldRewind() {
    _isHoldingRewind = false;
    _rewindTimer?.cancel();
  }
  
  /// Handle dead stream detection
  void _handleDeadStreamDetected() {
    print('Dead stream detected - attempting reconnection');
    print('Health status: $_healthStatus');
    print('Is stream healthy: $_isStreamHealthy');
    
    // Reset health monitor
    _healthMonitor.reset();
    
    // Attempt reconnection
    if (!_isReconnecting) {
      _attemptReconnect();
    }
  }
  
  /// Handle stream becoming healthy again
  void _handleStreamHealthy() {
    print('Stream health restored');
    // Stream is healthy, no action needed
  }
}
