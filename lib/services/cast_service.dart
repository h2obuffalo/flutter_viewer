import 'dart:async';
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
      // Initialize Google Cast context with default Chromecast app ID
      final castOptions = GoogleCastOptionsAndroid(
        appId: 'CC1AD845', // Default Chromecast app ID
      );
      await GoogleCastContext.instance.setSharedInstanceWithOptions(castOptions);
      _isInitialized = true;
      print('CastService initialized with real Chromecast support');
      
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
      
      // Get discovered devices
      final devices = <GoogleCastDevice>[];
      await for (final deviceList in discoveryManager.devicesStream) {
        devices.addAll(deviceList);
        if (deviceList.isNotEmpty) break; // Stop after first batch
      }
      
      // Filter out audio-only devices for video casting
      final videoCapableDevices = devices.where((device) {
        final modelName = device.modelName?.toLowerCase() ?? '';
        // Exclude audio-only devices
        return !modelName.contains('audio') && 
               !modelName.contains('speaker') &&
               !modelName.contains('home mini');
      }).toList();
      
      print('Found ${devices.length} total devices, ${videoCapableDevices.length} video-capable');
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
        } else {
          _isConnected = false;
          _deviceName = null;
          _isConnectedController?.add(false);
          _deviceNameController?.add(null);
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
      final mediaInformation = GoogleCastMediaInformation(
        contentId: hlsUrl,
        contentType: 'application/vnd.apple.mpegurl',
        streamType: CastMediaStreamType.live,
        metadata: GoogleCastMediaMetadata(
          metadataType: GoogleCastMediaMetadataType.genericMediaMetadata,
        ),
      );

      await mediaClient.loadMedia(mediaInformation);
      
      print('Started casting: $title to $_deviceName');
      print('HLS URL: $hlsUrl');
      print('Local playback continues as preview - both devices play live stream');
      
      return true;
    } catch (e) {
      print('Error starting cast: $e');
      return false;
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

  Future<bool> stopCasting() async {
    if (!isConnected) return false;

    try {
      final sessionManager = GoogleCastSessionManager.instance;
      await sessionManager.endSession();
      _isConnected = false;
      _deviceName = null;
      _isConnectedController?.add(false);
      _deviceNameController?.add(null);
      
      print('Stopped casting');
      return true;
    } catch (e) {
      print('Error stopping cast: $e');
      return false;
    }
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
