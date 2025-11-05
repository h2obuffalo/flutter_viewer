# Chromecast Integration for P2P Live Streaming

This document describes the Chromecast integration implemented in the Flutter viewer app, including troubleshooting, configuration, and best practices learned from implementation.

## Overview

The Chromecast integration allows users to:
- Discover and connect to Chromecast devices on the same network
- Cast HLS live streams to Chromecast devices
- Control playback (play, pause) on the Chromecast device
- Handle both iOS and Android platforms

## Architecture

### Components

1. **CastService** (`lib/services/cast_service.dart`)
   - Manages device discovery and connection
   - Handles casting operations using `flutter_chrome_cast` package
   - Provides connection state streams for UI updates
   - Auto-loads HLS stream on device connection

2. **CastButton** (`lib/widgets/cast_button.dart`)
   - UI component for device selection and casting
   - Retro-cyberpunk styling consistent with the app theme
   - Device discovery and connection interface

3. **SimplePlayerScreen** (`lib/screens/simple_player_screen.dart`)
   - Integrated video player with Chromecast support
   - Automatically pauses local player when casting starts
   - Resumes local player when casting stops

## Critical Configuration

### HLS Stream Requirements for Chromecast

Chromecast has specific requirements for HLS streams that must be met:

#### 1. **MIME Type**
- **Required**: `application/vnd.apple.mpegurl` for HLS M3U8 playlists
- **Alternative**: `application/x-mpegURL` (fallback)
- **❌ DO NOT USE**: `video/mp2t` (this is for TS segments, not playlists)

```dart
final mediaInformation = GoogleCastMediaInformation(
  contentId: hlsUrl,
  contentUrl: Uri.parse(hlsUrl),
  contentType: 'application/vnd.apple.mpegurl', // ✅ Correct
  streamType: CastMediaStreamType.live,
);
```

#### 2. **HLS Playlist Format**

The broadcaster must generate HLS manifests with the correct format:

```m3u8
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:123
#EXT-X-PLAYLIST-TYPE:LIVE  # ✅ Use LIVE for continuous live streams
#EXT-X-PROGRAM-DATE-TIME:2025-01-04T12:00:00.000Z
#EXTINF:6.000,
https://example.com/chunk1.ts
#EXTINF:6.000,
https://example.com/chunk2.ts
```

**Critical Points:**
- **Use `LIVE` not `EVENT`**: `#EXT-X-PLAYLIST-TYPE:LIVE` is required for continuous live streams
- `EVENT` playlists expect an `#EXT-X-ENDLIST` tag, which live streams never have
- Chromecast will reject `EVENT` playlists without endlist tags

#### 3. **Stream Type**
- Use `CastMediaStreamType.live` for live HLS streams
- `CastMediaStreamType.buffered` is for on-demand content

#### 4. **Segment Duration**
- Recommended: 4-6 seconds per segment for optimal Chromecast compatibility
- Chromecast has a ~20 second buffer limitation
- Smaller segments reduce latency and improve compatibility

### MediaInformation Structure

The `GoogleCastMediaInformation` object must be structured correctly:

```dart
final mediaInformation = GoogleCastMediaInformation(
  contentId: hlsUrl,           // String URL to M3U8 playlist
  contentUrl: Uri.parse(hlsUrl), // Uri object of the same URL
  contentType: 'application/vnd.apple.mpegurl',
  streamType: CastMediaStreamType.live,
  // Metadata is optional and can be omitted if causing serialization issues
);
```

**Important Notes:**
- Both `contentId` (String) and `contentUrl` (Uri) should be provided
- Metadata can sometimes cause serialization issues on iOS/Android bridges
- If experiencing `INVALID_REQUEST` errors, try removing metadata first

## Common Issues and Solutions

### Issue: `INVALID_REQUEST` Error (Error Code 2)

**Symptoms:**
- Logcat shows: `onMessageSendFailed: urn:x-cast:com.google.cast.media 2 INVALID_REQUEST`
- Flutter logs show: `Media Information is NULL`

**Causes:**
1. Wrong MIME type (`video/mp2t` instead of `application/vnd.apple.mpegurl`)
2. Wrong playlist type (`EVENT` instead of `LIVE`)
3. Missing or incorrect `contentId`/`contentUrl`
4. Metadata serialization issues on iOS/Android bridge

**Solutions:**
1. ✅ Use correct MIME type: `application/vnd.apple.mpegurl`
2. ✅ Ensure broadcaster generates `#EXT-X-PLAYLIST-TYPE:LIVE`
3. ✅ Verify both `contentId` and `contentUrl` are set
4. ✅ Try removing metadata if serialization issues persist

### Issue: Duplicate Cast Attempts

**Symptoms:**
- TV shows multiple cast connection attempts
- Auto-load fires multiple times

**Cause:**
- Multiple session listeners registered without cleanup

**Solution:**
```dart
// Cancel existing subscriptions before connecting
await _sessionSubscription?.cancel();
_sessionSubscription = null;
await _mediaStatusSubscription?.cancel();
_mediaStatusSubscription = null;

// Then register new listener
_sessionSubscription = sessionManager.currentSessionStream.listen(...);
```

### Issue: Player Conflicts After Casting

**Symptoms:**
- Local player has trouble playing after casting stops
- Resource conflicts between local player and Chromecast

**Solution:**
- Automatically pause local player when casting starts
- Resume local player when casting stops

```dart
_castService.isConnectedStream.listen((connected) {
  if (connected && !wasCasting) {
    _videoPlayerController?.pause(); // Pause local
  } else if (!connected && wasCasting) {
    _videoPlayerController?.play(); // Resume local
  }
});
```

## Implementation Details

### Device Discovery

```dart
Future<List<GoogleCastDevice>> discoverDevices() async {
  final discoveryManager = GoogleCastDiscoveryManager.instance;
  discoveryManager.startDiscovery();
  await Future.delayed(const Duration(milliseconds: 500));
  var devices = discoveryManager.devices;
  
  // Wait longer if no devices found initially
  if (devices.isEmpty) {
    await Future.delayed(const Duration(seconds: 3));
    devices = discoveryManager.devices;
  }
  
  return _filterVideoCapableDevices(devices);
}
```

### Connection Flow

1. **Initialize Cast Service**: `CastService().initialize()`
2. **Discover Devices**: `discoverDevices()`
3. **Connect to Device**: `connectToDevice(device)`
4. **Auto-load Stream**: Automatically loads HLS stream after 700ms delay
5. **Manual Cast**: Can also call `startCasting(url, title)` manually

### Session Management

**Critical**: Always cancel subscriptions to prevent duplicates:

```dart
// Before connecting
await _sessionSubscription?.cancel();
_sessionSubscription = null;

// Register listener once
_sessionSubscription = sessionManager.currentSessionStream.listen((session) {
  if (session != null) {
    // Connected
    _isConnected = true;
    // Auto-load stream after delay
  } else {
    // Disconnected
    _resetConnectionState();
    await _mediaStatusSubscription?.cancel();
    _mediaStatusSubscription = null;
  }
});
```

## Platform-Specific Configuration

### iOS Configuration

**AppDelegate.swift:**
```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Info.plist** (required permissions):
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used to search for Chromecast devices</string>
<key>NSBonjourServices</key>
<array>
  <string>_googlecast._tcp</string>
</array>
```

### Android Configuration

**AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## Dependencies

```yaml
dependencies:
  flutter_chrome_cast: ^1.2.5
```

## Testing

### Verify HLS Playlist Format

Check that your broadcaster generates correct HLS manifests:

```bash
curl https://tv.danpage.uk/live/playlist.m3u8 | head -20
```

Should show:
- `#EXT-X-PLAYLIST-TYPE:LIVE` (not EVENT)
- Correct MIME type headers
- Valid segment URLs

### Debug Logs

Enable verbose logging to debug casting issues:

```dart
print('Attempting to cast HLS stream to $_deviceName');
print('HLS URL: $hlsUrl');
print('Using application/vnd.apple.mpegurl content type');
```

Check Android logcat:
```bash
adb logcat | grep -iE "(cast|invalid|media|load|error)"
```

Look for:
- `INVALID_REQUEST` errors
- `Media Information is NULL` warnings
- Connection/disconnection events

## Known Working Configuration

Based on testing and debugging, the following configuration works reliably:

**CastService Implementation:**
- MIME Type: `application/vnd.apple.mpegurl`
- Stream Type: `CastMediaStreamType.live`
- No metadata (to avoid serialization issues)
- Auto-load delay: 700ms after connection
- Subscription cleanup before reconnecting

**Broadcaster HLS Manifest:**
- Playlist Type: `LIVE` (not `EVENT`)
- Target Duration: 6 seconds
- Media Sequence: Incremental
- Program Date Time: ISO format
- Valid segment URLs (R2 or CDN)

## Troubleshooting Checklist

- [ ] Verify HLS playlist uses `#EXT-X-PLAYLIST-TYPE:LIVE`
- [ ] Check MIME type is `application/vnd.apple.mpegurl`
- [ ] Ensure both `contentId` and `contentUrl` are set
- [ ] Verify stream type is `CastMediaStreamType.live`
- [ ] Check for duplicate session listeners
- [ ] Verify subscription cleanup on disconnect
- [ ] Test with broadcaster restarted (new manifest format)
- [ ] Check logcat for `INVALID_REQUEST` errors
- [ ] Verify network connectivity (same Wi-Fi)
- [ ] Test on both iOS and Android devices

## Future Enhancements

1. **Custom Receiver App**: Support for custom Chromecast receiver applications
2. **Playback Controls**: Add seek, volume, and other playback controls
3. **Queue Management**: Support for media queues
4. **Analytics**: Casting analytics and usage tracking
5. **Error Recovery**: Automatic retry logic for failed casts

## References

- [Google Cast SDK Documentation](https://developers.google.com/cast/docs)
- [HLS Streaming Specification](https://tools.ietf.org/html/rfc8216)
- [flutter_chrome_cast Package](https://pub.dev/packages/flutter_chrome_cast)
- [Chromecast HLS Compatibility Guide](https://developers.google.com/cast/docs/media)

## Changelog

### 2025-01-04
- Fixed MIME type from `video/mp2t` to `application/vnd.apple.mpegurl`
- Changed HLS playlist type from `EVENT` to `LIVE` for Chromecast compatibility
- Added subscription cleanup to prevent duplicate listeners
- Added automatic pause/resume for local player during casting
- Removed metadata parameter to avoid serialization issues
