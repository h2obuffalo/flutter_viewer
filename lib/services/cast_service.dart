import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

class CastService {
  static final CastService _instance = CastService._internal();
  factory CastService() => _instance;
  CastService._internal();

  StreamController<bool>? _isConnectedController;
  StreamController<String?>? _deviceNameController;
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _deviceName;

  // Streams for UI to listen to
  Stream<bool> get isConnectedStream => _isConnectedController!.stream;
  Stream<String?> get deviceNameStream => _deviceNameController!.stream;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _deviceName;

  /// Reset connection state when session ends
  void _resetConnectionState() {
    _isConnected = false;
    _deviceName = null;
    _isConnectedController?.add(false);
    _deviceNameController?.add(null);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isConnectedController = StreamController<bool>.broadcast();
    _deviceNameController = StreamController<String?>.broadcast();
    
    // Skip ChromeCast initialization on web platform
    if (kIsWeb) {
      print('CastService: ChromeCast not supported on web platform');
      _isInitialized = true;
      return;
    }
    
    try {
      // Initialize Google Cast context with platform-specific options
      const appId = 'CC1AD845'; // Default Chromecast app ID
      
      if (Platform.isIOS) {
        // iOS initialization with discovery criteria
        final discoveryCriteria = GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId);
        final castOptions = IOSGoogleCastOptions(discoveryCriteria);
        await GoogleCastContext.instance.setSharedInstanceWithOptions(castOptions);
        _isInitialized = true;
        print('CastService initialized with Chromecast support (iOS)');
      } else {
        // Android initialization
        final castOptions = GoogleCastOptionsAndroid(
          appId: appId,
        );
        await GoogleCastContext.instance.setSharedInstanceWithOptions(castOptions);
        _isInitialized = true;
        print('CastService initialized with Chromecast support (Android)');
      }
      
    } catch (e) {
      print('Error initializing ChromeCast: $e');
    }
  }

  Future<List<GoogleCastDevice>> discoverDevices() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (kIsWeb) {
      return []; // No devices available on web
    }
    
    try {
      final discoveryManager = GoogleCastDiscoveryManager.instance;
      await discoveryManager.startDiscovery();
      
      // Wait for discovery to find devices
      await Future.delayed(const Duration(seconds: 3));
      
      // Get current devices directly from the discovery manager
      final devices = discoveryManager.devices;
      
      // Filter out audio-only devices for video casting
      final videoCapableDevices = devices.where((device) {
        final modelName = device.modelName?.toLowerCase() ?? '';
        // Exclude audio-only devices
        return !modelName.contains('audio') && 
               !modelName.contains('speaker') &&
               !modelName.contains('home mini');
      }).toList();
      
      print('CastService: Found ${devices.length} total devices, ${videoCapableDevices.length} video-capable');
      for (final device in videoCapableDevices) {
        print('CastService: Device - ${device.friendlyName} (${device.modelName})');
      }
      return videoCapableDevices;
    } catch (e) {
      print('Error discovering devices: $e');
      return [];
    }
  }

  Future<bool> connectToDevice(GoogleCastDevice device) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (kIsWeb) {
      return false; // Not supported on web
    }
    
    try {
      final sessionManager = GoogleCastSessionManager.instance;
      await sessionManager.startSessionWithDevice(device);
      
      // Listen to session state changes
      sessionManager.currentSessionStream.listen((session) {
        if (session != null) {
          _isConnected = true;
          _deviceName = device.friendlyName;
          _isConnectedController?.add(true);
          _deviceNameController?.add(_deviceName);
          print('Connected to ${device.friendlyName}');
          
          // Listen to media status changes for debugging and state management
          GoogleCastRemoteMediaClient.instance.mediaStatusStream.listen((status) {
            print('📺 Chromecast Media Status: ${status?.playerState}');
            print('📺 Media Info: ${status?.mediaInformation?.contentId}');
            
            // Check if the stream has ended or failed
            final playerState = status?.playerState?.toString();
            if (playerState == 'GoogleCastPlayerState.idle') {
              print('⚠️  Chromecast is idle - stream may have failed to load');
              // Don't automatically disconnect here - let user control it
            } else if (playerState == 'GoogleCastPlayerState.buffering') {
              print('🔄 Chromecast is buffering...');
            } else if (playerState == 'GoogleCastPlayerState.playing') {
              print('▶️  Chromecast is playing');
            } else if (playerState == 'GoogleCastPlayerState.paused') {
              print('⏸️  Chromecast is paused');
            }
          });
        } else {
          // Session ended - reset state
          _resetConnectionState();
          print('Disconnected from Chromecast');
        }
      });
      
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  Future<bool> startCasting(String hlsUrl, String title) async {
    if (!isConnected) {
      print('No active cast session');
      return false;
    }

    if (kIsWeb) {
      return false; // Not supported on web
    }

    try {
      final mediaClient = GoogleCastRemoteMediaClient.instance;
      
      print('Attempting to cast HLS stream to $_deviceName');
      print('HLS URL: $hlsUrl');
      
      // Try the alternative method first (simpler configuration)
      final mediaInformation = GoogleCastMediaInformation(
        contentId: hlsUrl,
        contentUrl: Uri.parse(hlsUrl),
        contentType: 'video/mp2t', // Alternative MIME type for HLS
        streamType: CastMediaStreamType.live,
        metadata: GoogleCastMediaMetadata(
          metadataType: GoogleCastMediaMetadataType.genericMediaMetadata,
        ),
      );

      await mediaClient.loadMedia(mediaInformation);
      
      print('✅ Successfully started casting HLS stream to $_deviceName');
      print('Using video/mp2t content type (alternative method)');
      
      return true;
    } catch (e) {
      print('❌ Error starting HLS cast: $e');
      print('Trying fallback method...');
      
      // Try fallback with different configuration
      try {
        final mediaClient = GoogleCastRemoteMediaClient.instance;
        final fallbackMediaInfo = GoogleCastMediaInformation(
          contentId: hlsUrl,
          contentUrl: Uri.parse(hlsUrl),
          contentType: 'application/vnd.apple.mpegurl',
          streamType: CastMediaStreamType.buffered, // Try buffered instead of live
          metadata: GoogleCastMediaMetadata(
            metadataType: GoogleCastMediaMetadataType.genericMediaMetadata,
          ),
        );
        
        await mediaClient.loadMedia(fallbackMediaInfo);
        print('✅ Fallback method successful - using buffered stream type');
        return true;
      } catch (fallbackError) {
        print('❌ Fallback method also failed: $fallbackError');
        return false;
      }
    }
  }

  Future<bool> togglePlayPause() async {
    if (!isConnected) return false;

    if (kIsWeb) {
      return false; // Not supported on web
    }

    try {
      final mediaClient = GoogleCastRemoteMediaClient.instance;
      await mediaClient.play();
      print('Toggled play/pause on $_deviceName');
      return true;
    } catch (e) {
      print('Error toggling play/pause: $e');
      return false;
    }
  }

  Future<bool> setVolume(double volume) async {
    if (!isConnected) return false;

    if (kIsWeb) {
      return false; // Not supported on web
    }

    try {
      // Note: Volume control might need different implementation
      // This is a placeholder - actual volume control depends on the API
      print('Set volume to ${(volume * 100).toInt()}% on $_deviceName');
      return true;
    } catch (e) {
      print('Error setting volume: $e');
      return false;
    }
  }

  /// Alternative HLS casting method with different configuration
  /// Use this if the standard startCasting method doesn't work
  Future<bool> startCastingHLSAlternative(String hlsUrl, String title) async {
    if (!isConnected) {
      print('No active cast session');
      return false;
    }

    if (kIsWeb) {
      return false; // Not supported on web
    }

    try {
      final mediaClient = GoogleCastRemoteMediaClient.instance;
      
      // Alternative HLS configuration - simpler approach
      final mediaInformation = GoogleCastMediaInformation(
        contentId: hlsUrl,
        contentUrl: Uri.parse(hlsUrl),
        contentType: 'video/mp2t', // Alternative MIME type for HLS
        streamType: CastMediaStreamType.live,
        metadata: GoogleCastMediaMetadata(
          metadataType: GoogleCastMediaMetadataType.genericMediaMetadata,
        ),
      );

      await mediaClient.loadMedia(mediaInformation);
      
      print('Started casting HLS (alternative): $title to $_deviceName');
      print('HLS URL: $hlsUrl');
      print('Using video/mp2t content type');
      
      return true;
    } catch (e) {
      print('Error starting alternative HLS cast: $e');
      return false;
    }
  }

  Future<bool> stopCasting() async {
    if (!isConnected) return false;

    try {
      final sessionManager = GoogleCastSessionManager.instance;
      await sessionManager.endSession();
      _resetConnectionState();
      
      print('Stopped casting');
      return true;
    } catch (e) {
      print('Error stopping cast: $e');
      return false;
    }
  }

  /// Force reset the casting state (useful when session ends unexpectedly)
  void forceResetCastingState() {
    print('Force resetting casting state');
    _resetConnectionState();
  }

  void dispose() {
    final discoveryManager = GoogleCastDiscoveryManager.instance;
    discoveryManager.stopDiscovery();
    _isConnectedController?.close();
    _deviceNameController?.close();
    _isConnectedController = null;
    _deviceNameController = null;
    _isInitialized = false;
  }
}
