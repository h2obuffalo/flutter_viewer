class AppConstants {
  // API Endpoints - Production URLs via Cloudflare Tunnel
  static const String signalingUrl = 'wss://tv.danpage.uk/ws';
  static const String authApiUrl = 'https://tv.danpage.uk';
  static const String lineupApiUrl = 'https://tv.danpage.uk';
  
  // HLS Stream URLs - Production URLs via Cloudflare Tunnel  
  static const String hlsManifestUrl = 'https://tv.danpage.uk/hls/stream.m3u8';
  static const String cloudflareR2BaseUrl = 'https://pub-81f1de5a4fc945bdaac36449630b5685.r2.dev';
  
  // Lineup API Endpoint
  static const String lineupJsonUrl = '${lineupApiUrl}/lineup/lineup.json';
  
  // P2P Configuration
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const int maxChunksInMemory = 30;
  static const int proxyServerPort = 8080;
  
  // Stream Configuration
  static const int targetLatencyMs = 5000; // 5 seconds
  static const int playerBufferMs = 10000; // 10 seconds
  
  // UI Configuration
  static const Duration controlsHideDelay = Duration(seconds: 3);
  static const Duration splashScreenDuration = Duration(seconds: 3);
  
  // Retro UI Constants
  static const double retroBorderWidth = 2.0;
  static const double glowRadius = 10.0;
}

// Stream Quality Options
enum StreamQuality {
  low('Low (480p)', '480'),
  medium('Medium (720p)', '720'),
  high('High (1080p)', '1080');
  
  final String label;
  final String value;
  
  const StreamQuality(this.label, this.value);
}
