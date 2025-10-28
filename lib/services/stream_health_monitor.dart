import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Service to monitor stream health and detect dead/stuck streams
class StreamHealthMonitor {
  static final StreamHealthMonitor _instance = StreamHealthMonitor._internal();
  factory StreamHealthMonitor() => _instance;
  StreamHealthMonitor._internal();

  // Stream health monitoring
  Timer? _healthCheckTimer;
  Duration? _lastKnownPosition;
  int _samePositionCount = 0;
  int _consecutiveErrors = 0;
  DateTime? _lastSegmentTime;
  String? _lastSegmentId;
  int _lastBufferedEnd = 0;
  int _sameBufferedEndCount = 0;
  
  // Configuration - Very conservative for live streaming
  static const int maxSamePositionCount = 50; // Much more tolerant for live streams
  static const int maxSameBufferedEndCount = 20; // Very tolerant of stable buffered end
  static const int maxConsecutiveErrors = 10; // Allow many errors before giving up
  static const Duration healthCheckInterval = Duration(seconds: 60); // Very infrequent checks
  static const Duration segmentTimeout = Duration(seconds: 120); // Very long timeout for live
  
  // Callbacks
  Function()? _onDeadStreamDetected;
  Function()? _onStreamHealthy;
  
  // Stream controllers for health status
  StreamController<bool>? _isHealthyController;
  StreamController<String>? _healthStatusController;
  
  // Getters
  Stream<bool> get isHealthyStream => _isHealthyController!.stream;
  Stream<String> get healthStatusStream => _healthStatusController!.stream;
  
  bool get isHealthy => _consecutiveErrors < maxConsecutiveErrors && _samePositionCount < maxSamePositionCount;
  
  /// Initialize the health monitor
  void initialize({
    Function()? onDeadStreamDetected,
    Function()? onStreamHealthy,
  }) {
    _onDeadStreamDetected = onDeadStreamDetected;
    _onStreamHealthy = onStreamHealthy;
    
    _isHealthyController = StreamController<bool>.broadcast();
    _healthStatusController = StreamController<String>.broadcast();
    
    _startHealthMonitoring();
    
    if (kDebugMode) {
      print('StreamHealthMonitor: Initialized with dead stream detection');
    }
  }
  
  /// Start periodic health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    
    // Delay initial health monitoring to avoid false positives during stream startup
    Timer(const Duration(seconds: 30), () {
      _healthCheckTimer = Timer.periodic(healthCheckInterval, (_) {
        _performHealthCheck();
      });
    });
  }
  
  /// Update stream position for monitoring
  void updateStreamPosition(Duration position, {String? segmentId}) {
    final now = DateTime.now();
    
    // For live streams, position monitoring is less reliable
    // Focus more on buffered end changes and errors
    if (_lastKnownPosition != null && _lastKnownPosition == position) {
      _samePositionCount++;
      if (kDebugMode) {
        print('StreamHealthMonitor: Same position detected $_samePositionCount times: ${position.inSeconds}s');
      }
    } else {
      // Position changed, reset counter
      _samePositionCount = 0;
      _consecutiveErrors = 0;
      _lastSegmentTime = now;
      _lastSegmentId = segmentId;
      
      if (kDebugMode) {
        print('StreamHealthMonitor: Position updated to ${position.inSeconds}s');
      }
    }
    
    _lastKnownPosition = position;
    
    // Disable position-based dead stream detection for live streams
    // Position monitoring is completely unreliable for live content
    // Only rely on buffered end and error monitoring
    
    // Check for segment timeout - more lenient for live streams
    if (_lastSegmentTime != null && 
        now.difference(_lastSegmentTime!) > segmentTimeout) {
      _handleDeadStreamDetected('No new segments for ${segmentTimeout.inSeconds} seconds');
    }
  }
  
  /// Update buffered end position - better indicator of new segments
  void updateBufferedEnd(Duration bufferedEnd) {
    final bufferedEndSeconds = bufferedEnd.inSeconds;
    final now = DateTime.now();
    
    // Check if buffered end has changed (new segments loaded)
    if (_lastBufferedEnd != 0 && _lastBufferedEnd == bufferedEndSeconds) {
      _sameBufferedEndCount++;
      if (kDebugMode) {
        print('StreamHealthMonitor: Same buffered end detected $_sameBufferedEndCount times: ${bufferedEndSeconds}s');
      }
    } else {
      // Buffered end changed, reset counter and update timestamp
      _sameBufferedEndCount = 0;
      _consecutiveErrors = 0;
      _lastSegmentTime = now;
      _lastBufferedEnd = bufferedEndSeconds;
      
      if (kDebugMode) {
        print('StreamHealthMonitor: Buffered end updated to ${bufferedEndSeconds}s');
      }
    }
    
    // Only check for dead stream based on buffered end if it's been stuck for a very long time
    // and we have a substantial buffer size (not just starting)
    if (_sameBufferedEndCount >= maxSameBufferedEndCount && 
        bufferedEndSeconds > 30) { // Only check if we have at least 30 seconds buffered
      _handleDeadStreamDetected('Stream buffered end stuck at ${bufferedEndSeconds}s for ${_sameBufferedEndCount} checks');
    }
  }
  
  /// Report a stream error
  void reportError(String error) {
    _consecutiveErrors++;
    
    if (kDebugMode) {
      print('StreamHealthMonitor: Error reported ($_consecutiveErrors/$maxConsecutiveErrors): $error');
    }
    
    if (_consecutiveErrors >= maxConsecutiveErrors) {
      _handleDeadStreamDetected('Too many consecutive errors: $error');
    }
  }
  
  /// Report successful stream activity
  void reportSuccess() {
    if (_consecutiveErrors > 0) {
      _consecutiveErrors = 0;
      _samePositionCount = 0;
      
      if (kDebugMode) {
        print('StreamHealthMonitor: Stream recovered, resetting error counters');
      }
      
      _notifyStreamHealthy();
    }
  }
  
  /// Perform periodic health check
  void _performHealthCheck() {
    if (_lastKnownPosition == null) {
      // No position data yet, skip check
      return;
    }
    
    final now = DateTime.now();
    
    // Check if we haven't received updates recently
    if (_lastSegmentTime != null && 
        now.difference(_lastSegmentTime!) > segmentTimeout) {
      _handleDeadStreamDetected('No stream updates for ${segmentTimeout.inSeconds} seconds');
    }
    
    // Update health status
    _updateHealthStatus();
  }
  
  /// Handle dead stream detection
  void _handleDeadStreamDetected(String reason) {
    if (kDebugMode) {
      print('StreamHealthMonitor: Dead stream detected - $reason');
    }
    
    _isHealthyController?.add(false);
    _healthStatusController?.add('Dead stream detected: $reason');
    
    _onDeadStreamDetected?.call();
  }
  
  /// Notify that stream is healthy
  void _notifyStreamHealthy() {
    _isHealthyController?.add(true);
    _healthStatusController?.add('Stream healthy');
    
    _onStreamHealthy?.call();
  }
  
  /// Update health status
  void _updateHealthStatus() {
    final isCurrentlyHealthy = isHealthy;
    _isHealthyController?.add(isCurrentlyHealthy);
    
    String status;
    if (_consecutiveErrors > 0) {
      status = 'Stream errors: $_consecutiveErrors/$maxConsecutiveErrors';
    } else if (_samePositionCount > 0) {
      status = 'Same position: $_samePositionCount/$maxSamePositionCount';
    } else {
      status = 'Stream healthy';
    }
    
    _healthStatusController?.add(status);
  }
  
  /// Reset all monitoring data
  void reset() {
    _lastKnownPosition = null;
    _samePositionCount = 0;
    _consecutiveErrors = 0;
    _lastSegmentTime = null;
    _lastSegmentId = null;
    _lastBufferedEnd = 0;
    _sameBufferedEndCount = 0;
    
    _notifyStreamHealthy();
    
    if (kDebugMode) {
      print('StreamHealthMonitor: Reset all monitoring data');
    }
  }
  
  /// Dispose the health monitor
  void dispose() {
    _healthCheckTimer?.cancel();
    _isHealthyController?.close();
    _healthStatusController?.close();
    
    _isHealthyController = null;
    _healthStatusController = null;
    _onDeadStreamDetected = null;
    _onStreamHealthy = null;
    
    if (kDebugMode) {
      print('StreamHealthMonitor: Disposed');
    }
  }
}
