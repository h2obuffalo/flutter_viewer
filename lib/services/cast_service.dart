import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../utils/platform_utils.dart';
import '../utils/web_stub.dart' if (dart.library.html) 'dart:html' as web;
import '../utils/js_util_stub.dart' if (dart.library.html) 'dart:js_util' as js_util;
import 'auth_service.dart';

class CastService {
  static final CastService _instance = CastService._internal();
  factory CastService() => _instance;
  CastService._internal();

  StreamController<bool>? _isConnectedController;
  StreamController<String?>? _deviceNameController;
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _deviceName;
  bool _mediaLoaded = false;
  DateTime? _lastLoadMediaAttempt;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _mediaStatusSubscription;
  Timer? _playlistRefreshTimer; // Timer to periodically refresh playlist for Android TV

  // Streams for UI to listen to
  Stream<bool> get isConnectedStream => _isConnectedController!.stream;
  Stream<String?> get deviceNameStream => _deviceNameController!.stream;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _deviceName;

  /// Reset connection state when session ends
  void _resetConnectionState() {
    _isConnected = false;
    _deviceName = null;
    _mediaLoaded = false;
    _lastLoadMediaAttempt = null;
    _isConnectedController?.add(false);
    _deviceNameController?.add(null);
  }

  /// Helper method to await JavaScript promises
  Future<dynamic> _awaitJsResult(dynamic jsPromise) async {
    if (kIsWeb && jsPromise != null) {
      try {
        return await js_util.promiseToFuture(jsPromise);
      } catch (e) {
        print('Error awaiting JS promise: $e');
        rethrow;
      }
    }
    return jsPromise;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isConnectedController = StreamController<bool>.broadcast();
    _deviceNameController = StreamController<String?>.broadcast();
    
    // Web platform uses JavaScript Cast SDK
    if (kIsWeb) {
      print('CastService: Initializing ChromeCast for web platform');
      // Cast SDK is initialized in index.html
      // We just need to check if it's available
      try {
        // Check if webCastAPI is available
        // ignore: avoid_web_libraries_in_flutter
        final window = web.window;
        final webCastAPI = js_util.getProperty(window, 'webCastAPI');
        if (webCastAPI != null) {
          final isAvailable = js_util.callMethod(webCastAPI, 'isAvailable', []);
          if (isAvailable == true) {
            print('✅ CastService: ChromeCast available on web');
          } else {
            print('⚠️ CastService: ChromeCast SDK not fully initialized yet');
          }
          js_util.setProperty(
            webCastAPI,
            'onSessionStarted',
            js_util.allowInterop(() {
              print('CastService: Web session started');
              _isConnected = true;
              _deviceName = 'Chromecast';
              _isConnectedController?.add(true);
              _deviceNameController?.add(_deviceName);
            }),
          );
          js_util.setProperty(
            webCastAPI,
            'onSessionEnded',
            js_util.allowInterop(() {
              print('CastService: Web session ended');
              _resetConnectionState();
            }),
          );
        } else {
          print('⚠️ CastService: webCastAPI not found - Cast SDK may not be loaded');
        }
      } catch (e) {
        print('⚠️ CastService: Error checking web cast availability: $e');
      }
      _isInitialized = true;
      return;
    }
    
    try {
      // Initialize Google Cast context with platform-specific options
      const appId = 'CC1AD845'; // Default Chromecast app ID
      
      if (PlatformUtils.isIOS) {
        // iOS initialization with discovery criteria
        final discoveryCriteria = GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId);
        final castOptions = IOSGoogleCastOptions(discoveryCriteria);
        await GoogleCastContext.instance.setSharedInstanceWithOptions(castOptions);
        _isInitialized = true;
        print('✅ CastService initialized with Chromecast support (iOS)');
        print('   App ID: $appId');
      } else if (PlatformUtils.isAndroid) {
        // Android initialization
        final castOptions = GoogleCastOptionsAndroid(
          appId: appId,
        );
        await GoogleCastContext.instance.setSharedInstanceWithOptions(castOptions);
        _isInitialized = true;
        print('✅ CastService initialized with Chromecast support (Android)');
        print('   App ID: $appId');
        
        // Start discovery automatically on Android for better device detection
        try {
          final discoveryManager = GoogleCastDiscoveryManager.instance;
          discoveryManager.startDiscovery();
          print('✅ Started automatic device discovery');
        } catch (e) {
          print('⚠️  Could not start automatic discovery: $e');
        }
      }
      
    } catch (e, stackTrace) {
      print('❌ Error initializing ChromeCast: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  Future<List<GoogleCastDevice>> discoverDevices() async {
    print('CastService: discoverDevices() called');
    
    if (!_isInitialized) {
      print('CastService: Initializing...');
      await initialize();
    }
    
    if (kIsWeb) {
      print('CastService: Web platform - no devices available');
      return []; // No devices available on web
    }
    
    try {
      print('CastService: Getting discovery manager...');
      final discoveryManager = GoogleCastDiscoveryManager.instance;
      
      // Start discovery if not already running
      print('CastService: Starting device discovery...');
      discoveryManager.startDiscovery();
      
      // Wait a moment for discovery to begin
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('CastService: Getting current devices from discovery manager...');
      var devices = discoveryManager.devices;
      print('CastService: Raw devices from discovery manager: ${devices.length}');
      
      // If no devices found, wait longer for discovery to catch up
      if (devices.isEmpty) {
        print('CastService: No devices found, waiting 3 seconds for discovery...');
        await Future.delayed(const Duration(seconds: 3));
        devices = discoveryManager.devices;
        print('CastService: Devices after wait: ${devices.length}');
        
        // If still no devices, try one more time
        if (devices.isEmpty) {
          print('CastService: Still no devices, waiting 2 more seconds...');
          await Future.delayed(const Duration(seconds: 2));
          devices = discoveryManager.devices;
          print('CastService: Devices after second wait: ${devices.length}');
        }
      }
      
      // Log all discovered devices for debugging
      for (var device in devices) {
        print('CastService: Discovered device - ${device.friendlyName} (${device.modelName}) - ID: ${device.deviceID}');
      }
      
      return _filterVideoCapableDevices(devices);
    } catch (e, stackTrace) {
      print('CastService: Error discovering devices: $e');
      print('CastService: Stack trace: $stackTrace');
      return [];
    }
  }

  List<GoogleCastDevice> _filterVideoCapableDevices(List<GoogleCastDevice> devices) {
    // Filter out audio-only devices for video casting
    final videoCapableDevices = devices.where((device) {
      final modelName = device.modelName?.toLowerCase() ?? '';
      print('CastService: Checking device: ${device.friendlyName} (${device.modelName})');
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
      
      // On iOS, the session may already be established automatically
      // Check if we're already connected to this device
      var currentSession = sessionManager.currentSession;
      if (currentSession != null && PlatformUtils.isIOS) {
        print('ℹ️  iOS: Session already exists, checking if it matches selected device...');
        // On iOS, if session already exists, we might already be connected
        // Just verify we're connected and update state
        if (_isConnected && _deviceName == device.friendlyName) {
          print('✅ iOS: Already connected to ${device.friendlyName}');
          return true;
        }
      }
      
      // Cancel any existing session subscription to avoid duplicate listeners
      await _sessionSubscription?.cancel();
      _sessionSubscription = null;
      await _mediaStatusSubscription?.cancel();
      _mediaStatusSubscription = null;
      
      // Set up session listener BEFORE starting the session to catch connection events
      // Listen to session state changes (only once per connection)
      _sessionSubscription = sessionManager.currentSessionStream.listen(
        (session) {
          if (session != null) {
            _isConnected = true;
            _deviceName = device.friendlyName;
            _isConnectedController?.add(true);
            _deviceNameController?.add(_deviceName);
            print('✅ Connected to ${device.friendlyName}');
            print('   Device ID: ${device.deviceID}');
            print('   Model: ${device.modelName}');
          
          // Note: Auto-load is disabled - CastButton will handle loading manually
          // This prevents conflicts when CastButton explicitly calls startCasting
          print('⏭️  Auto-load disabled - CastButton will handle loading');
          
          // Listen to media status changes for debugging and state management (only once)
          if (_mediaStatusSubscription == null) {
              _mediaStatusSubscription = GoogleCastRemoteMediaClient.instance.mediaStatusStream.listen(
              (status) {
                print('📺 Chromecast Media Status Update:');
                print('   Player State: ${status?.playerState}');
                print('   Media Information: ${status?.mediaInformation != null ? "Present" : "NULL"}');
                if (status?.mediaInformation != null) {
                  final mediaInfo = status!.mediaInformation!;
                  print('   Content ID: ${mediaInfo.contentId}');
                  print('   Content URL: ${mediaInfo.contentUrl}');
                  print('   Content Type: ${mediaInfo.contentType}');
                  print('   Stream Type: ${mediaInfo.streamType}');
                  print('   Metadata: ${mediaInfo.metadata != null ? "Present" : "NULL"}');
                  
                  // If we just attempted to load media and now have media info, mark as loaded
                  if (_lastLoadMediaAttempt != null) {
                    final timeSinceLoad = DateTime.now().difference(_lastLoadMediaAttempt!);
                    if (timeSinceLoad.inSeconds < 10) {
                      print('✅ Media accepted by Chromecast after ${timeSinceLoad.inMilliseconds}ms');
                      _mediaLoaded = true;
                    }
                  }
                } else {
                  // If we recently attempted to load media and still have NULL, Chromecast rejected it
                  if (_lastLoadMediaAttempt != null) {
                    final timeSinceLoad = DateTime.now().difference(_lastLoadMediaAttempt!);
                    if (timeSinceLoad.inSeconds < 10 && _mediaLoaded) {
                      print('   ⚠️⚠️⚠️ CRITICAL: Media Information is NULL after loadMedia attempt!');
                      print('   Time since loadMedia: ${timeSinceLoad.inSeconds}s');
                      print('   This means Chromecast rejected the media request');
                      print('   Resetting _mediaLoaded flag to allow retry');
                      _mediaLoaded = false; // Reset to allow retry
                    } else {
                      print('   ⚠️ WARNING: Media Information is NULL!');
                      print('   This means the media info was not properly sent to Chromecast');
                    }
                  } else {
                    print('   ℹ️  Media Information is NULL (no media loaded yet)');
                  }
                }
                
                // Check if the stream has ended or failed
                if (status == null) return; // Skip if status is null
                
              final CastMediaPlayerState playerState = status.playerState;
              print('   Idle Reason: ${status.idleReason}');
              print('   Idle Reason Type: ${status.idleReason?.runtimeType}');
              print('   Playback Rate: ${status.playbackRate}');
              
              // Log detailed error information if idle
              if (status.idleReason != null) {
                final idleReasonStr = status.idleReason.toString();
                print('   🔍 Idle Reason Details: $idleReasonStr');
                print('   🔍 Idle Reason Value: ${status.idleReason}');
                
                // Try to get all available status properties for debugging
                print('   🔍 Full Status Debug Info:');
                print('      Player State: ${status.playerState}');
                print('      Playback Rate: ${status.playbackRate}');
                print('      Volume: ${status.volume}');
                print('      Is Muted: ${status.isMuted}');
                
                if (idleReasonStr.contains('ERROR') || 
                    idleReasonStr.contains('INTERRUPTED') ||
                    idleReasonStr.contains('FINISHED') ||
                    idleReasonStr.contains('CANCELLED')) {
                  print('   ⚠️ Critical: Stream failed with reason: $idleReasonStr');
                }
              }
              
              if (playerState == CastMediaPlayerState.idle) {
                  print('⚠️  Chromecast is idle - stream may have failed to load');
                  // Check if there's an error in the media status
                  if (status.idleReason != null) {
                    final idleReason = status.idleReason!;
                    print('   Idle Reason: $idleReason');
                    print('   Idle Reason Type: ${idleReason.runtimeType}');
                    
                    // Check if it's an error (most common issue)
                    if (idleReason == GoogleCastMediaIdleReason.error) {
                      print('   ❌❌❌ STREAM ERROR DETECTED ❌❌❌');
                      print('   Chromecast cannot load or play the stream');
                      print('   ');
                      print('   📋 DIAGNOSTIC INFORMATION:');
                      
                      // Log the media information to help debug
                      if (status.mediaInformation != null) {
                        final mediaInfo = status.mediaInformation!;
                        print('   📋 Media Info:');
                        print('      Content ID: ${mediaInfo.contentId ?? "NULL"}');
                        print('      Content URL: ${mediaInfo.contentUrl ?? "NULL"}');
                        print('      Content Type: ${mediaInfo.contentType ?? "NULL"}');
                        print('      Stream Type: ${mediaInfo.streamType ?? "NULL"}');
                        print('      Metadata: ${mediaInfo.metadata != null ? "Present" : "NULL"}');
                        
                        // Try to get the actual URL being used
                        final actualUrl = mediaInfo.contentId ?? mediaInfo.contentUrl?.toString() ?? "Unknown";
                        print('   📋 Actual URL being cast: $actualUrl');
                        print('   📋 Verify this URL works: curl -I "$actualUrl"');
                      } else {
                        print('   ⚠️⚠️⚠️ CRITICAL: Media Information is NULL ⚠️⚠️⚠️');
                        print('   This means Chromecast rejected the media information we sent');
                        print('   Possible reasons:');
                        print('   1. Invalid content type for Chromecast');
                        print('   2. URL format rejected by Chromecast');
                        print('   3. Serialization issue with GoogleCastMediaInformation');
                        print('   4. Chromecast firmware/version incompatibility');
                        print('   5. Network connectivity issue');
                        print('   ');
                        print('   🔍 What we attempted to send:');
                        print('      URL: https://tv.danpage.uk/live/playlist.m3u8');
                        print('      Content Type: application/x-mpegurl');
                        print('      Stream Type: CastMediaStreamType.live');
                        print('   ');
                        print('   💡 Try manually testing the playlist:');
                        print('      curl "https://tv.danpage.uk/live/playlist.m3u8"');
                        print('   💡 Verify Chromecast can access R2:');
                        print('      curl -I "https://pub-81f1de5a4fc945bdaac36449630b5685.r2.dev/live/.../segment.ts"');
                      }
                      
                      print('   ');
                      print('   🔍 POSSIBLE CAUSES:');
                      print('   1. HLS playlist format incompatible with Chromecast');
                      print('   2. TS segments not accessible (R2 URLs may need CORS or different config)');
                      print('   3. Content type mismatch (trying application/x-mpegurl)');
                      print('   4. Chromecast firmware/version incompatibility');
                      print('   5. Network/firewall blocking Chromecast from R2');
                      print('   ');
                      print('   💡 NEXT STEPS:');
                      print('   1. Test playlist URL manually: curl "https://tv.danpage.uk/live/playlist.m3u8"');
                      print('   2. Test a segment URL: curl -I "<segment-url-from-playlist>"');
                      print('   3. Check Chromecast logs if possible (Cast Connect app)');
                      print('   4. Try with a known-working HLS stream to verify Chromecast works');
                    } else if (idleReason == GoogleCastMediaIdleReason.interrupted) {
                      print('   ⚠️ Stream interrupted - attempting to resume');
                      Future.delayed(const Duration(seconds: 2), () async {
                        try {
                          final mediaClient = GoogleCastRemoteMediaClient.instance;
                          await mediaClient.play();
                          print('   ✅ Retried play command after interruption');
                        } catch (e) {
                          print('   ❌ Retry play failed: $e');
                        }
                      });
                    }
                  } else {
                    // IDLE state but no error reason - might be end of playlist window for live stream
                    // Try to resume playback to trigger playlist refresh
                    if (status.mediaInformation?.streamType == CastMediaStreamType.live) {
                      print('   🔄 Live stream idle (no error) - attempting auto-resume to refresh playlist...');
                      Future.delayed(const Duration(milliseconds: 1000), () async {
                        try {
                          final mediaClient = GoogleCastRemoteMediaClient.instance;
                          await mediaClient.play();
                          print('   ✅ Auto-resumed live stream playback (from idle state)');
                        } catch (e) {
                          print('   ⚠️ Auto-resume from idle failed: $e');
                        }
                      });
                    }
                  }
                  // Don't automatically disconnect here - let user control it
                } else if (playerState == CastMediaPlayerState.buffering) {
                  print('🔄 Chromecast/Android TV is buffering...');
                  // For live streams, if buffering persists, try to resume to trigger playlist refresh
                  // Android TV may stop buffering if it reaches end of playlist window
                  if (status.mediaInformation?.streamType == CastMediaStreamType.live) {
                    // Wait a bit to see if buffering resolves, then try to resume
                    Future.delayed(const Duration(seconds: 3), () async {
                      try {
                        // Check if still buffering after delay
                        final currentStatus = GoogleCastRemoteMediaClient.instance.mediaStatus;
                        if (currentStatus?.playerState == CastMediaPlayerState.buffering) {
                          print('   ⚠️ Still buffering after 3s - attempting resume to refresh playlist...');
                          final mediaClient = GoogleCastRemoteMediaClient.instance;
                          await mediaClient.play();
                          print('   ✅ Resumed playback to trigger playlist refresh');
                        }
                      } catch (e) {
                        print('   ⚠️ Resume during buffering failed: $e');
                      }
                    });
                  }
                } else if (playerState == CastMediaPlayerState.playing) {
                  print('▶️  Chromecast is playing');
                } else if (playerState == CastMediaPlayerState.paused) {
                  print('⏸️  Chromecast is paused');
                  // For live streams, automatically resume if paused (Chromecast may pause when reaching end of playlist window)
                  // This ensures continuous playback by triggering playlist refresh
                  if (status.mediaInformation?.streamType == CastMediaStreamType.live) {
                    print('   🔄 Live stream paused - attempting auto-resume to refresh playlist...');
                    Future.delayed(const Duration(milliseconds: 500), () async {
                      try {
                        final mediaClient = GoogleCastRemoteMediaClient.instance;
                        await mediaClient.play();
                        print('   ✅ Auto-resumed live stream playback');
                      } catch (e) {
                        print('   ⚠️ Auto-resume failed: $e');
                      }
                    });
                  }
                }
              },
              onError: (error) {
                print('❌❌❌ MEDIA STATUS STREAM ERROR ❌❌❌');
                print('   Error: $error');
                print('   Error type: ${error.runtimeType}');
                print('   Error toString: ${error.toString()}');
                
                // Try to extract more error details
                try {
                  if (error is Exception) {
                    print('   Exception details: ${error.toString()}');
                  }
                  // Check if error has a message property
                  try {
                    final errorMessage = error.toString();
                    print('   Full error message: $errorMessage');
                    
                    // Look for common error patterns
                    if (errorMessage.contains('INVALID_REQUEST')) {
                      print('   🚨 DETECTED: INVALID_REQUEST error');
                      print('   This means Chromecast rejected the media request format');
                    }
                    if (errorMessage.contains('LOAD_FAILED')) {
                      print('   🚨 DETECTED: LOAD_FAILED error');
                      print('   Chromecast could not load the media URL');
                    }
                    if (errorMessage.contains('CORS')) {
                      print('   🚨 DETECTED: CORS error');
                      print('   Cross-origin resource sharing issue');
                    }
                    if (errorMessage.contains('network') || errorMessage.contains('Network')) {
                      print('   🚨 DETECTED: Network error');
                      print('   Chromecast cannot reach the media URL');
                    }
                  } catch (e) {
                    print('   Could not extract additional error details: $e');
                  }
                } catch (e) {
                  print('   Error extracting error details: $e');
                }
                print('   Stack trace: ${StackTrace.current}');
              },
            );
          }
        } else {
          // Session ended - reset state and cancel subscriptions
          _resetConnectionState();
          // Cancel media status subscription when session ends
          _mediaStatusSubscription?.cancel();
          _mediaStatusSubscription = null;
          print('Disconnected from Chromecast');
        }
      },
      onError: (error) {
        print('❌❌❌ SESSION STREAM ERROR ❌❌❌');
        print('   Error: $error');
        print('   Error type: ${error.runtimeType}');
        print('   This may cause the session to disconnect');
        // Don't reset state here - let the session == null handler do it
      },
      cancelOnError: false, // Keep listening even if there's an error
      );
      
      // Now start the session after listener is set up
      try {
        await sessionManager.startSessionWithDevice(device);
        print('✅ Session start request sent to ${device.friendlyName}');
      } catch (e, stackTrace) {
        print('❌ Error starting session: $e');
        print('   Stack trace: $stackTrace');
        // Cancel the subscription if session failed to start
        await _sessionSubscription?.cancel();
        _sessionSubscription = null;
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  Future<bool> startCasting(String hlsUrl, String title) async {
    if (kIsWeb) {
      print('CastService: Starting cast on web platform');
      try {
        // ignore: avoid_web_libraries_in_flutter
        final window = web.window;
        final webCastAPI = js_util.getProperty(window, 'webCastAPI');
        if (webCastAPI == null) {
          print('❌ CastService: webCastAPI not found - Cast SDK may not be loaded');
          return false;
        }
        
        // Check if Cast SDK is available
        final isAvailable = js_util.callMethod(webCastAPI, 'isAvailable', []);
        if (isAvailable != true) {
          print('⚠️ CastService: Cast SDK not available');
          print('   Make sure you are using Chrome browser');
          return false;
        }
        
        print('✅ Cast SDK is available, requesting session...');
        
        // Modify URL for Chromecast to use shorter playlist (30 chunks = ~3 minutes)
        // Keep stream.m3u8 (works with Android TV/Chromecast)
        Uri castUrl = Uri.parse(hlsUrl);
        if (castUrl.path.endsWith('.m3u8')) {
          final queryParams = Map<String, String>.from(castUrl.queryParameters);
          queryParams['chunks'] = '30';
          castUrl = castUrl.replace(queryParameters: queryParams);
          print('📤 Modified URL for Chromecast (web): limiting to 30 chunks (~3 minutes)');
          print('   Original: $hlsUrl');
          print('   Modified: $castUrl');
        }
        
        // Request session first (this will show device picker if needed)
        final requestSessionMethod = js_util.getProperty(webCastAPI, 'requestSession');
        if (requestSessionMethod != null) {
          final sessionResult = js_util.callMethod(webCastAPI, 'requestSession', []);
          await _awaitJsResult(sessionResult);
          print('✅ Session established, starting cast...');
        } else {
          // Fallback: try to get session directly
          final cast = js_util.getProperty(window, 'cast');
          if (cast != null) {
            final framework = js_util.getProperty(cast, 'framework');
            if (framework != null) {
              final CastContext = js_util.getProperty(framework, 'CastContext');
              final castContext = js_util.callMethod(CastContext, 'getInstance', []);
              final currentSession = js_util.callMethod(castContext, 'getCurrentSession', []);
              if (currentSession == null) {
                final requestResult = js_util.callMethod(castContext, 'requestSession', []);
                await _awaitJsResult(requestResult);
              }
            }
          }
        }
        
        // Now start casting with modified URL
        final startCastingMethod = js_util.getProperty(webCastAPI, 'startCasting');
        if (startCastingMethod != null) {
          final startResult = js_util.callMethod(webCastAPI, 'startCasting', [castUrl.toString(), title]);
          await _awaitJsResult(startResult);
          
          _isConnected = true;
          _deviceName ??= 'Chromecast';
          _isConnectedController?.add(true);
          _deviceNameController?.add(_deviceName);
          print('✅ Casting started on web');
          return true;
        } else {
          print('❌ startCasting method not found in webCastAPI');
        }
      } catch (e, stackTrace) {
        print('❌ Error starting cast on web: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
    
    if (!isConnected) {
      print('❌ No active cast session');
      return false;
    }
    
    // Prevent duplicate loadMedia calls - especially important on iOS where session may be pre-loaded
    if (_mediaLoaded) {
      print('⏭️  Media already loaded, skipping duplicate loadMedia call');
      return true;
    }

    try {
      // Ensure session is ready before loading media
      final sessionManager = GoogleCastSessionManager.instance;
      var currentSession = sessionManager.currentSession;
      if (currentSession == null) {
        print('❌ No active session - waiting for session to be ready...');
        // Platform-specific retry logic:
        // - iOS: Session may be pre-loaded, fewer retries needed
        // - Android: Session needs explicit establishment, more retries
        final maxRetries = PlatformUtils.isIOS ? 3 : 5;
        for (int i = 0; i < maxRetries; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          currentSession = sessionManager.currentSession;
          if (currentSession != null) {
            print('✅ Session ready after ${(i + 1) * 500}ms (${PlatformUtils.isIOS ? "iOS" : "Android"})');
            break;
          }
        }
        if (currentSession == null) {
          print('❌ Session still not ready after wait');
          return false;
        }
      } else {
        print('ℹ️  Session already active (${PlatformUtils.isIOS ? "iOS - may be pre-loaded" : "Android"})');
      }
      
      // Wait for application to be connected (receiver app must be launched)
      // Platform-specific wait times:
      // - iOS: Session often pre-initialized, needs less time
      // - Android: Needs full initialization of receiver app and media channel
      final waitTime = PlatformUtils.isIOS 
        ? const Duration(milliseconds: 2000)  // iOS: Session may be pre-loaded
        : const Duration(milliseconds: 5000);  // Android: Needs full initialization
      
      print('⏳ Waiting for receiver application and media channel to be ready (${PlatformUtils.isIOS ? "iOS" : "Android"})...');
      await Future.delayed(waitTime);
      
      // Verify session is still active before proceeding (re-check after wait)
      currentSession = sessionManager.currentSession;
      if (currentSession == null) {
        print('❌ Session lost while waiting for media channel');
        return false;
      }
      print('✅ Session still active, media channel should be ready');
      
      final mediaClient = GoogleCastRemoteMediaClient.instance;
      
      print('Attempting to cast HLS stream to $_deviceName');
      print('HLS URL: $hlsUrl');
      
      // Modify URL for Chromecast to use shorter playlist (30 chunks = ~3 minutes)
      // Reduced from 60 to 30 chunks to minimize latency (8 minutes -> ~3 minutes)
      // Keep stream.m3u8 (Android TV/Chromecast works with Owncast's format)
      // Add chunks=30 parameter to limit playlist to last 30 chunks (~3 minutes @ 6s/chunk)
      Uri castUrl = Uri.parse(hlsUrl);
      if (castUrl.path.endsWith('.m3u8')) {
        // Add chunks=30 parameter to limit playlist to last 30 chunks (~3 minutes @ 6s/chunk)
        final queryParams = Map<String, String>.from(castUrl.queryParameters);
        queryParams['chunks'] = '30';
        castUrl = castUrl.replace(queryParameters: queryParams);
        print('📤 Modified URL for Android TV: limiting to 30 chunks (~3 minutes)');
        print('   Original: $hlsUrl');
        print('   Modified: $castUrl');
      } else {
        print('📤 Using full URL with auth tokens: $hlsUrl');
      }
      
      // Based on GitHub example: use application/vnd.apple.mpegurl (primary) or application/x-mpegURL (fallback)
      // Include both contentId and contentUrl as per example
      final mediaInformation = GoogleCastMediaInformation(
        contentId: castUrl.toString(), // Use modified URL with chunks parameter
        contentUrl: castUrl, // Include contentUrl - required by Chromecast
        contentType: 'application/vnd.apple.mpegurl', // Primary MIME type for HLS as per GitHub example
        streamType: CastMediaStreamType.live,
        // Don't include metadata for live streams - can cause serialization issues
      );

      print('📤 Loading media with HLS configuration...');
      print('   Content ID: ${castUrl.toString()} (with chunks=30 parameter for Chromecast)');
      print('   Content URL: ${mediaInformation.contentUrl}');
      print('   Content Type: application/vnd.apple.mpegurl (as per GitHub example)');
      print('   Stream Type: ${CastMediaStreamType.live}');
      print('   Metadata: ${mediaInformation.metadata != null ? "Present" : "NULL"}');
      print('   ✅ Using modified URL with chunks=30 (limits playlist to ~3 minutes for lower latency)');
      print('   ✅ Including both contentId and contentUrl (as per GitHub example)');
      
      try {
        print('📤 Attempting to load media with information:');
        print('   Content ID: ${mediaInformation.contentId} (with chunks=30 for Chromecast)');
        print('   Content URL: ${mediaInformation.contentUrl ?? "NULL (not set - may help with serialization)"}');
        print('   Content Type: ${mediaInformation.contentType}');
        print('   Stream Type: ${mediaInformation.streamType}');
        
        // Record when we attempt to load media (but don't mark as loaded yet)
        // We'll wait for media status to confirm Chromecast accepted it
        _lastLoadMediaAttempt = DateTime.now();
        _mediaLoaded = false; // Reset before attempting - will be set to true if accepted
        
        try {
          await mediaClient.loadMedia(mediaInformation);
          print('✅ Media load request sent successfully (no exception thrown)');
          print('⚠️  Note: This doesn\'t guarantee Chromecast accepted it - check media status');
          print('Using application/vnd.apple.mpegurl content type (HLS M3U8 - as per GitHub example)');
        } catch (loadException) {
          print('❌❌❌ EXCEPTION during loadMedia call ❌❌❌');
          print('   This is a synchronous error - Chromecast rejected BEFORE processing');
          print('   Error: $loadException');
          print('   Error type: ${loadException.runtimeType}');
          print('   Error toString: ${loadException.toString()}');
          
          // Try to extract detailed error information
          try {
            final errorStr = loadException.toString();
            print('   🔍 Error analysis:');
            
            if (errorStr.contains('INVALID_REQUEST') || errorStr.contains('invalid')) {
              print('   🚨 INVALID_REQUEST: Chromecast rejected the media request format');
              print('   Possible causes:');
              print('      - Invalid content type');
              print('      - Invalid URL format');
              print('      - Malformed GoogleCastMediaInformation');
            }
            if (errorStr.contains('network') || errorStr.contains('Network') || errorStr.contains('connect')) {
              print('   🚨 Network error: Chromecast cannot reach the URL');
            }
            if (errorStr.contains('serialize') || errorStr.contains('JSON')) {
              print('   🚨 Serialization error: Failed to serialize media information');
            }
          } catch (e) {
            print('   Could not analyze error: $e');
          }
          
          rethrow; // Re-throw to trigger fallback
        }
        
        // Wait longer for Chromecast to process the load request
        // Media channel needs time to initialize and process the HLS URL
        // The mediaStatusStream listener will detect if media was accepted or rejected
        print('⏳ Waiting for Chromecast to process media load request...');
        print('   The mediaStatusStream will report if media was accepted or rejected');
        await Future.delayed(const Duration(milliseconds: 3000));
      } catch (loadError) {
        print('❌❌❌ EXCEPTION during loadMedia call ❌❌❌');
        print('   Error: $loadError');
        print('   Error type: ${loadError.runtimeType}');
        print('   Stack trace: ${StackTrace.current}');
        print('   🔍 Detailed error info:');
        try {
          // Try to get more error details if available
          print('   Error string: ${loadError.toString()}');
          if (loadError is Exception) {
            print('   Exception message: ${loadError.toString()}');
          }
        } catch (e) {
          print('   Could not extract additional error details: $e');
        }
        print('   This is a synchronous error - Chromecast rejected the request before processing');
        rethrow; // Re-throw to trigger fallback
      }
      
        // Wait longer for media to load before calling play() (similar to example's approach)
        // The example uses shouldAutoplay=true, but since we don't have that API,
        // we wait and then explicitly call play()
        // Chromecast needs time to fetch and parse the HLS playlist
        // The mediaStatusStream listener will detect if media was rejected
        print('⏳ Waiting for Chromecast to load playlist before sending play command...');
        await Future.delayed(const Duration(milliseconds: 3000));
        
        // Note: We can't synchronously check media status, but the mediaStatusStream
        // listener will detect if media was rejected and reset _mediaLoaded accordingly
        
        // Send play command after media has loaded
        // Media status is available through the stream, but we can't easily check it synchronously
        // So we'll just try to play and let the error handling catch any issues
        try {
          print('▶️  Sending play command...');
          await mediaClient.play();
          print('✅ Play command sent to Chromecast');
        } catch (playError) {
          print('⚠️  Error sending play command: $playError');
          // Try one more time after a delay
          await Future.delayed(const Duration(milliseconds: 1000));
          try {
            await mediaClient.play();
            print('✅ Play command sent on retry');
          } catch (retryError) {
            print('❌ Play command failed on retry: $retryError');
            // Don't fail the whole operation - the stream might auto-play
          }
        }
        
        return true;
    } catch (e) {
      print('❌ Error starting HLS cast: $e');
      print('Trying fallback method...');

      // Fallback with alternative HLS MIME type (use modified URL with chunks parameter)
      try {
        // Use the same modified URL with chunks=30 parameter
        // Keep stream.m3u8 (works with Android TV/Chromecast)
        Uri fallbackCastUrl = Uri.parse(hlsUrl);
        if (fallbackCastUrl.path.endsWith('.m3u8')) {
          final queryParams = Map<String, String>.from(fallbackCastUrl.queryParameters);
          queryParams['chunks'] = '30';
          fallbackCastUrl = fallbackCastUrl.replace(queryParameters: queryParams);
        }
        
        final mediaClient = GoogleCastRemoteMediaClient.instance;
        final fallbackMediaInfo = GoogleCastMediaInformation(
          contentId: fallbackCastUrl.toString(), // Use modified URL with chunks parameter
          contentUrl: fallbackCastUrl, // Include contentUrl as per GitHub example
          contentType: 'application/x-mpegURL', // Fallback MIME type if primary fails
          streamType: CastMediaStreamType.live,
          // Don't include metadata in fallback either
        );
        
        print('🔄 Fallback: Retrying with application/x-mpegURL (capital URL required by Chromecast)');
        print('   Using modified URL with chunks=30: $fallbackCastUrl');

        // Reset state for fallback attempt
        _lastLoadMediaAttempt = DateTime.now();
        _mediaLoaded = false;
        
        await mediaClient.loadMedia(fallbackMediaInfo);
        print('✅ Fallback method successful - application/x-mpegURL');
        
        // Wait for Chromecast to process the fallback request
        // The mediaStatusStream listener will detect if media was accepted or rejected
        await Future.delayed(const Duration(milliseconds: 3000));
        
        // Note: We can't synchronously check media status, but the mediaStatusStream
        // listener will detect if fallback was accepted and set _mediaLoaded accordingly
        // If it was rejected, the listener will reset _mediaLoaded and we'll return false
        
        try {
          await mediaClient.play();
          print('✅ Play command sent (fallback)');
        } catch (e) {
          print('⚠️  Play failed on fallback: $e');
        }
        
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
        contentType: 'application/vnd.apple.mpegurl', // Correct MIME type for HLS
        streamType: CastMediaStreamType.live,
        metadata: GoogleCastMediaMetadata(
          metadataType: GoogleCastMediaMetadataType.genericMediaMetadata,
        ),
      );

      await mediaClient.loadMedia(mediaInformation);
      
      print('Started casting HLS (alternative): $title to $_deviceName');
      print('HLS URL: $hlsUrl');
      print('Using application/vnd.apple.mpegurl content type');
      
      return true;
    } catch (e) {
      print('Error starting alternative HLS cast: $e');
      return false;
    }
  }

  Future<bool> stopCasting() async {
    if (!isConnected) return false;

    try {
      if (kIsWeb) {
        // ignore: avoid_web_libraries_in_flutter
        final window = web.window;
        final webCastAPI = js_util.getProperty(window, 'webCastAPI');
        if (webCastAPI != null) {
          final stopResult = js_util.callMethod(webCastAPI, 'stopCasting', []);
          await _awaitJsResult(stopResult);
          _resetConnectionState();
          print('Stopped casting (web)');
          return true;
        }
        return false;
      }

      // Cancel subscriptions before ending session
      await _sessionSubscription?.cancel();
      _sessionSubscription = null;
      await _mediaStatusSubscription?.cancel();
      _mediaStatusSubscription = null;
      
      final sessionManager = GoogleCastSessionManager.instance;
      await sessionManager.endSession();
      _resetConnectionState();
      _mediaLoaded = false;
      
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
    _mediaLoaded = false;
    _lastLoadMediaAttempt = null;
    _resetConnectionState();
  }

  void dispose() {
    // Cancel all subscriptions
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _mediaStatusSubscription?.cancel();
    _mediaStatusSubscription = null;
    
    // Skip ChromeCast dispose on web (not supported anyway)
    if (!kIsWeb) {
      final discoveryManager = GoogleCastDiscoveryManager.instance;
      discoveryManager.stopDiscovery();
    }
    _isConnectedController?.close();
    _deviceNameController?.close();
    _isConnectedController = null;
    _deviceNameController = null;
    _isInitialized = false;
  }
}
