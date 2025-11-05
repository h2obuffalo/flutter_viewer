import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/artist.dart';
import '../config/theme.dart';

/// Widget for displaying SoundCloud audio players
/// Shows embedded player with 2-3 tracks for artists with SoundCloud
class AudioPlayerSection extends StatefulWidget {
  final Artist artist;

  const AudioPlayerSection({
    super.key,
    required this.artist,
  });

  @override
  State<AudioPlayerSection> createState() => _AudioPlayerSectionState();
}

class _AudioPlayerSectionState extends State<AudioPlayerSection> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // Show SoundCloud player if available
    if (widget.artist.soundcloud != null) {
      return _buildSoundCloudPlayer();
    }
    
    // Show nothing if no SoundCloud
    return const SizedBox.shrink();
  }

  Widget _buildSoundCloudPlayer() {
    final soundcloudUrl = widget.artist.soundcloud!;
    
    // SoundCloud embed URL format
    // Using iframe embed for user profile/tracks
    final embedUrl = 'https://w.soundcloud.com/player/?url=${Uri.encodeComponent(soundcloudUrl)}&color=%2300ffff&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RetroTheme.retroBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MUSIC',
            style: TextStyle(
              color: RetroTheme.neonCyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, // Ensure full width
            height: 450, // Height for 2-3 tracks
            decoration: BoxDecoration(
              border: Border.all(color: RetroTheme.neonCyan.withValues(alpha: 0.3), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _isLoading
                  ? Container(
                      color: RetroTheme.darkBlue,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: RetroTheme.neonCyan,
                        ),
                      ),
                    )
                  : _hasError
                      ? const SizedBox.shrink() // Show nothing on error
                      : SizedBox.expand(
                          child: WebViewWidget(
                            controller: _webViewController!,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeWebView(); // Fire and forget - async initialization
  }

  Future<void> _initializeWebView() async {
    if (widget.artist.soundcloud == null) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    final soundcloudUrl = Uri.encodeComponent(widget.artist.soundcloud!);
    final embedUrl = 'https://w.soundcloud.com/player/?url=$soundcloudUrl&color=%2300ffff&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(RetroTheme.darkBlue)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('SoundCloud WebView: Page started loading: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            print('SoundCloud WebView: Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('SoundCloud WebView Error: ${error.description} (${error.errorCode})');
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('SoundCloud WebView: Navigation request to ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          print('SoundCloud WebView JS message: ${message.message}');
        },
      );
    
    print('SoundCloud WebView: Loading URL: $embedUrl');
    await _webViewController!.loadRequest(Uri.parse(embedUrl));
  }
}

