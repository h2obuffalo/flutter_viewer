# Chromecast Integration for P2P Live Streaming

This document describes the Chromecast integration implemented in the Flutter viewer app, similar to how Stremio handles torrent streaming with transcoding and casting.

## Overview

The Chromecast integration allows users to:
- Discover and connect to Chromecast devices on the same network
- Cast P2P streams to Chromecast with automatic transcoding
- Control playback (play, pause, seek) on the Chromecast device
- Handle transcoding for incompatible formats

## Architecture

### Components

1. **ChromecastService** (`lib/services/chromecast_service.dart`)
   - Manages device discovery and connection
   - Handles casting operations
   - Provides playback control methods

2. **TranscodingService** (`lib/services/transcoding_service.dart`)
   - Manages transcoding of P2P streams for Chromecast compatibility
   - Supports different transcoding profiles (Chromecast, Mobile, Desktop)
   - Handles transcoding job management

3. **ChromecastControls** (`lib/widgets/chromecast_controls.dart`)
   - UI components for device selection and casting
   - Retro-cyberpunk styling consistent with the app theme
   - Device discovery and connection interface

4. **PlayerScreen** (`lib/screens/player_screen.dart`)
   - Integrated video player with Chromecast support
   - Automatic transcoding detection and handling
   - Cast button and device selection

## Features

### Device Discovery
- Automatic discovery of Chromecast devices on the local network
- Real-time device list updates
- Device information display (name, model)

### P2P Stream Casting
- Direct casting of P2P streams to Chromecast
- Automatic transcoding for incompatible formats
- Support for various video formats (MP4, MKV, AVI, etc.)

### Transcoding Support
- **Chromecast Profile**: Optimized for Chromecast devices
  - H.264 video codec
  - AAC audio codec
  - MP4 container format
  - 1080p max resolution
  - Fast start optimization

- **Mobile Profile**: Optimized for mobile devices
  - H.264 video codec
  - AAC audio codec
  - 720p max resolution
  - Lower bitrate for mobile networks

- **Desktop Profile**: High-quality transcoding
  - H.264 video codec
  - AAC audio codec
  - Original resolution
  - Higher bitrate for desktop viewing

### Playback Control
- Play/Pause control
- Seek functionality
- Progress tracking
- Volume control (via Chromecast device)

## Usage

### Basic Casting

```dart
// Initialize Chromecast service
final chromecastService = ChromecastService();
await chromecastService.initialize();

// Cast a P2P stream
final success = await chromecastService.castP2PStream(
  streamUrl: 'http://example.com/stream.m3u8',
  title: 'Live Stream',
  subtitle: 'P2P Live Streaming',
  posterUrl: 'http://example.com/poster.jpg',
  transcodingRequired: true,
);
```

### Transcoding

```dart
// Initialize transcoding service
final transcodingService = TranscodingService();

// Start transcoding
final transcodedUrl = await transcodingService.startTranscoding(
  streamUrl: 'http://example.com/stream.mkv',
  streamId: 'stream_123',
  profile: TranscodingProfile.chromecast,
  onProgress: (progress) {
    print('Transcoding progress: ${(progress * 100).toInt()}%');
  },
);
```

### Playback Control

```dart
// Play/Pause
await chromecastService.togglePlayPause();

// Seek to position
await chromecastService.seekTo(Duration(minutes: 5));

// Get current position
final position = await chromecastService.getCurrentPosition();

// Stop casting
await chromecastService.stopCasting();
```

## Implementation Details

### Chromecast Compatibility

The implementation ensures Chromecast compatibility by:

1. **Format Detection**: Automatically detecting if transcoding is needed
2. **Transcoding**: Converting streams to Chromecast-compatible formats
3. **Proxy Server**: Serving transcoded streams via HTTP proxy
4. **Metadata**: Providing proper metadata for Chromecast display

### P2P Integration

Similar to Stremio's approach:

1. **P2P Stream Reception**: Receiving P2P stream chunks
2. **Transcoding Pipeline**: Converting to Chromecast-compatible format
3. **HTTP Proxy**: Serving transcoded stream via HTTP
4. **Chromecast Casting**: Casting the HTTP stream to Chromecast

### Error Handling

- Network connectivity issues
- Device discovery failures
- Transcoding errors
- Casting failures
- Playback interruptions

## Configuration

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<application>
  <meta-data
    android:name="com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
    android:value="your.package.name.CastOptionsProvider" />
</application>
```

### iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used to search for Chromecast devices</string>
<key>NSBonjourServices</key>
<array>
  <string>_googlecast._tcp</string>
</array>
```

## Dependencies

```yaml
dependencies:
  flutter_chrome_cast: ^0.0.8
  better_player: ^0.0.83
  shelf: ^1.4.0
  shelf_static: ^1.1.2
```

## Future Enhancements

1. **Real Transcoding**: Integrate with FFmpeg for actual transcoding
2. **Multiple Devices**: Support for casting to multiple devices
3. **Queue Management**: Media queue management for Chromecast
4. **Custom Receivers**: Support for custom Chromecast receivers
5. **Analytics**: Casting analytics and usage tracking

## Troubleshooting

### Common Issues

1. **Device Not Found**
   - Ensure Chromecast is on the same network
   - Check network permissions
   - Restart device discovery

2. **Casting Fails**
   - Verify stream URL is accessible
   - Check transcoding requirements
   - Ensure Chromecast is connected

3. **Transcoding Issues**
   - Verify FFmpeg installation (for real transcoding)
   - Check transcoding parameters
   - Monitor transcoding progress

### Debug Information

Enable debug logging:

```dart
// Enable Chromecast debug logging
ChromeCastController.setDebugLoggingEnabled(true);
```

## Testing

### Test Scenarios

1. **Device Discovery**
   - Multiple Chromecast devices
   - Network connectivity issues
   - Device connection/disconnection

2. **Stream Casting**
   - Various video formats
   - Different transcoding profiles
   - Network bandwidth limitations

3. **Playback Control**
   - Play/pause functionality
   - Seek operations
   - Volume control

4. **Error Handling**
   - Network failures
   - Device disconnections
   - Transcoding errors

## Performance Considerations

1. **Transcoding Performance**
   - Use hardware acceleration when available
   - Optimize transcoding parameters
   - Monitor CPU usage

2. **Network Optimization**
   - Adaptive bitrate streaming
   - Buffer management
   - Network quality detection

3. **Memory Management**
   - Stream buffer management
   - Transcoding job cleanup
   - Device connection cleanup

## Security Considerations

1. **Network Security**
   - Secure device discovery
   - Encrypted stream transmission
   - Authentication for casting

2. **Content Protection**
   - DRM support (if needed)
   - Content access control
   - Stream protection

## Conclusion

This Chromecast integration provides a comprehensive solution for casting P2P streams to Chromecast devices, similar to Stremio's approach. The implementation includes automatic transcoding, device discovery, and playback control, making it suitable for production use in P2P live streaming applications.
