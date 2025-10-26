# Flutter Live Stream Viewer

A retro-cyberpunk themed P2P live streaming viewer app built with Flutter.

## Features

- 🎫 Ticket-based authentication
- 🎮 Retro-cyberpunk UI with glitch effects
- 🌐 WebRTC P2P streaming
- 📺 Better Player for video playback
- 🔄 Automatic HTTP fallback
- 📊 Real-time P2P statistics
- 📱 Support for Android phones, tablets, and Fire TV

## Architecture

```
Flutter App
├── Authentication (Ticket-based)
├── Signaling Service (WebSocket)
├── P2P Manager (WebRTC)
├── Local Proxy Server (HTTP)
├── Video Player (Better Player)
└── Retro UI
```

## Setup

### Prerequisites

- Flutter SDK 3.0+
- Android Studio or VS Code with Flutter extensions
- Android device or emulator for testing

### Installation

1. Navigate to the project directory:
```bash
cd flutter_viewer
```

2. Install dependencies:
```bash
flutter pub get
```

3. Download retro fonts (VT323, Courier Prime Code) and place in `assets/fonts/`

4. Run the app:
```bash
flutter run
```

## Configuration

Edit `lib/config/constants.dart` to configure:
- Signaling server URL
- Auth API URL
- P2P cache size
- Player buffer settings

## Development Status

This is an active development project. Currently implemented:

- ✅ Project structure
- ✅ Retro theme and styling
- ✅ Splash screen with glitch effects
- ✅ Authentication service
- ✅ Models (Ticket, Chunk, Stats)
- ⏳ Login screen (in progress)
- ⏳ Main menu (in progress)
- ⏳ P2P streaming (planned)
- ⏳ Video player integration (planned)
- ⏳ TV support (planned)

## Building for Release

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

## Dependencies

See `pubspec.yaml` for the complete list. Key packages:
- flutter_webrtc
- better_player
- shelf (local HTTP server)
- provider (state management)
- flutter_secure_storage

## License

MIT License - See LICENSE file for details
