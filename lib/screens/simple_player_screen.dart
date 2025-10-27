import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

/// Simple player screen for mobile platforms using video_player
/// with automatic reconnection and lifecycle handling
class SimplePlayerScreen extends StatefulWidget {
  const SimplePlayerScreen({super.key});

  @override
  State<SimplePlayerScreen> createState() => _SimplePlayerScreenState();
}

class _SimplePlayerScreenState extends State<SimplePlayerScreen> with WidgetsBindingObserver {
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
  bool _streamOnline = true;
  int _statusCheckAttempts = 0;
  static const int _maxStatusCheckAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivityListener();
    _initPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
    _statusCheckTimer?.cancel();
    _videoPlayerController?.dispose();
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
      print('Initializing video player with URL: ${AppConstants.hlsManifestUrl}');
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(AppConstants.hlsManifestUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize the controller
      await _videoPlayerController!.initialize();
      
      // Set up error handling
      _videoPlayerController!.addListener(() {
        if (_videoPlayerController!.value.hasError) {
          print('Video player error: ${_videoPlayerController!.value.errorDescription}');
          _errorMessage = _videoPlayerController!.value.errorDescription ?? 'Unknown error';
          if (!_isReconnecting) {
            _attemptReconnect();
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
    try {
      print('Attempting to reconnect...');
      
      _videoPlayerController?.dispose();
      
      setState(() {
        _isInitialized = false;
        _errorMessage = null;
      });
      
      await _initPlayer();
      
      setState(() {
        _isReconnecting = false;
        _reconnectAttempt = 0;
      });
      
      print('Reconnected successfully');
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'LIVE STREAM',
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
          const CircularProgressIndicator(color: Colors.cyan),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.cyan),
          SizedBox(height: 20),
          Text(
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
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController!),
          ),
        ),
        // Live indicator overlay
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
