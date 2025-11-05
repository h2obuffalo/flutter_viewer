import 'dart:async';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class TrackInfo {
  final String source; // Asset path or remote URL
  final String trackName;
  final String artistName;
  final bool isAsset; // true for assets, false for remote URLs

  TrackInfo({
    required this.source,
    required this.trackName,
    required this.artistName,
    this.isAsset = true,
  });
}

class CraicAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<TrackInfo> _tracks = [];
  int _currentTrackIndex = 0;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  bool _tracksLoaded = false;
  Completer<void>? _tracksLoadCompleter;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;

  CraicAudioService() {
    _setupAudioListeners();
    // Load tracks from API asynchronously
    _tracksLoadCompleter = Completer<void>();
    _loadTracksFromApi().then((_) {
      _tracksLoaded = true;
      _tracksLoadCompleter?.complete();
      _tracksLoadCompleter = null;
    }).catchError((e) {
      _tracksLoaded = true; // Even if failed, we have fallback tracks
      _tracksLoadCompleter?.complete();
      _tracksLoadCompleter = null;
    });
  }

  Completer<void>? _loadCompleter;
  
  void _setupAudioListeners() {
    // Listen to player state changes (only set up once)
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      print('Player state changed: playing=${state.playing}, processingState=${state.processingState}');
      // If we get to ready state, the source loaded successfully
      if (state.processingState == ProcessingState.ready && _loadCompleter != null && !_loadCompleter!.isCompleted) {
        print('Source loaded successfully!');
        _loadCompleter!.complete();
      }
    });
    
    // Listen to errors (only set up once)
    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen(
      (event) {
        print('Playback event: ${event.processingState}');
      },
      onError: (error) {
        print('AudioPlayer error: $error');
        // If we're waiting for load, complete with error
        if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
          _loadCompleter!.completeError(error);
        }
      },
    );
  }

  // Track metadata getters
  TrackInfo? get currentTrack {
    if (_tracks.isEmpty) return null;
    return _tracks[_currentTrackIndex];
  }

  String get currentTrackName => currentTrack?.trackName ?? '';
  String get currentArtistName => currentTrack?.artistName ?? '';

  bool get isPlaying => _isPlaying || _audioPlayer.playing;

  /// Load tracks from the API
  Future<void> _loadTracksFromApi() async {
    try {
      print('Loading audio tracks from API...');
      final url = Uri.parse('${AppConstants.lineupApiUrl}/lineup/admin/audio-tracks');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> tracksData = jsonDecode(response.body);
        print('Received ${tracksData.length} tracks from API');
        
        _tracks.clear();
        for (var trackData in tracksData) {
          final track = TrackInfo(
            source: trackData['audioUrl'] as String,
            trackName: trackData['trackName'] as String? ?? trackData['filename'] as String? ?? 'Untitled',
            artistName: trackData['artistName'] as String? ?? 'Unknown Artist',
            isAsset: false, // All API tracks are remote URLs
          );
          _tracks.add(track);
          print('Added track: ${track.trackName} by ${track.artistName}');
        }
        
        if (_tracks.isEmpty) {
          print('No tracks found in API, using fallback tracks');
          _initializeFallbackTracks();
        } else {
          print('Successfully loaded ${_tracks.length} tracks from API');
        }
      } else {
        print('Failed to load tracks from API: ${response.statusCode}');
        _initializeFallbackTracks();
      }
    } catch (e) {
      print('Error loading tracks from API: $e');
      _initializeFallbackTracks();
    }
  }

  /// Initialize with fallback tracks if API fails
  void _initializeFallbackTracks() {
    // Fallback to hardcoded assets if API fails
    _tracks.addAll([
      TrackInfo(
        source: 'assets/sounds/Dolphin & The Teknoist - Ppl Gonna Bleed.mp3',
        trackName: 'Ppl Gonna Bleed',
        artistName: 'Dolphin & The Teknoist',
        isAsset: true,
      ),
      TrackInfo(
        source: 'assets/sounds/Krest - SHOTS - 6 second clip.mp3',
        trackName: 'SHOTS',
        artistName: 'Krest',
        isAsset: true,
      ),
    ]);
    print('Initialized ${_tracks.length} fallback tracks');
  }
  
  /// Reload tracks from API (useful for refreshing after uploads)
  /// This is public so it can be called externally if needed
  Future<void> reloadTracks() async {
    await _loadTracksFromApi();
    // Reset index if it's out of bounds after reload
    if (_currentTrackIndex >= _tracks.length) {
      _currentTrackIndex = 0;
    }
  }
  
  /// Get the current number of tracks loaded
  int get trackCount => _tracks.length;

  /// Add a track to the pool
  void addTrack(TrackInfo track) {
    _tracks.add(track);
  }

  /// Set the tracks pool
  void setTracks(List<TrackInfo> tracks) {
    _tracks.clear();
    _tracks.addAll(tracks);
    if (_currentTrackIndex >= _tracks.length) {
      _currentTrackIndex = 0;
    }
  }

  /// Play the current track for 6 seconds
  Future<void> playCurrentTrack() async {
    // Wait for tracks to load if they haven't loaded yet
    if (!_tracksLoaded && _tracksLoadCompleter != null) {
      print('Waiting for tracks to load...');
      try {
        await _tracksLoadCompleter!.future.timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Timeout waiting for tracks to load: $e');
      }
    }
    
    if (_tracks.isEmpty) {
      print('No tracks available');
      return;
    }

    // Stop any currently playing audio
    await stop();

    final track = currentTrack;
    if (track == null) {
      print('No current track available');
      return;
    }

    try {
      _isPlaying = true;
      print('Attempting to play track: ${track.source}');
      print('Track name: ${track.trackName}, Artist: ${track.artistName}');

      // Play the track
      if (track.isAsset) {
        // Try both with and without assets/ prefix - just_audio might need the full path
        final assetPathWithoutPrefix = track.source.replaceFirst('assets/', '');
        final assetPathWithPrefix = track.source;
        print('Trying asset path without prefix: $assetPathWithoutPrefix');
        print('Trying asset path with prefix: $assetPathWithPrefix');
        print('Full source path: ${track.source}');
        
        // Use AudioSource.asset() - try both path formats
        _loadCompleter = Completer<void>();
        
        // Try without assets/ prefix first
        try {
          print('Calling setAudioSource with AudioSource.asset("$assetPathWithoutPrefix")');
          final audioSource = AudioSource.asset(assetPathWithoutPrefix);
          print('AudioSource created, now setting it on player');
          await _audioPlayer.setAudioSource(audioSource);
          print('setAudioSource call completed, waiting for source to load...');
          
          // Wait for the source to actually load (or error)
          await _loadCompleter!.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('Timeout waiting for source to load');
              throw TimeoutException('Source load timeout');
            },
          );
          
          print('Source loaded successfully, calling play()');
          await _audioPlayer.play();
          print('play() called successfully');
        } catch (setError, stackTrace) {
          print('Error with AudioSource.asset("$assetPathWithoutPrefix"): $setError');
          print('Stack trace: $stackTrace');
          _loadCompleter = null;
          
          // Try with assets/ prefix
          print('Trying with assets/ prefix: AudioSource.asset("$assetPathWithPrefix")');
          _loadCompleter = Completer<void>();
          try {
            final audioSource = AudioSource.asset(assetPathWithPrefix);
            await _audioPlayer.setAudioSource(audioSource);
            print('setAudioSource call completed with prefix, waiting for source to load...');
            await _loadCompleter!.future.timeout(const Duration(seconds: 5));
            print('Source loaded with prefix, calling play()');
            await _audioPlayer.play();
            print('play() called successfully with prefix');
          } catch (prefixError) {
            print('Error with AudioSource.asset("$assetPathWithPrefix"): $prefixError');
            _loadCompleter = null;
            
            // Fallback: try setAsset directly (older method)
            print('Trying fallback setAsset("$assetPathWithoutPrefix")');
            _loadCompleter = Completer<void>();
            try {
              await _audioPlayer.setAsset(assetPathWithoutPrefix);
              print('setAsset call completed, waiting for source to load...');
              await _loadCompleter!.future.timeout(const Duration(seconds: 5));
              print('Source loaded with setAsset, calling play()');
              await _audioPlayer.play();
              print('play() called successfully with setAsset');
            } catch (setAssetError, setAssetStackTrace) {
              print('Error with setAsset("$assetPathWithoutPrefix"): $setAssetError');
              print('setAsset stack trace: $setAssetStackTrace');
              _loadCompleter = null;
              rethrow;
            } finally {
              _loadCompleter = null;
            }
          } finally {
            _loadCompleter = null;
          }
        } finally {
          _loadCompleter = null;
        }
        print('Audio player play() called');
        
        // Wait a bit and check state
        await Future.delayed(const Duration(milliseconds: 500));
        final isPlaying = _audioPlayer.playing;
        print('Player playing state after play: $isPlaying');
        
        if (!isPlaying) {
          print('WARNING: Player is not playing!');
        }
      } else {
        print('Playing URL: ${track.source}');
        await _audioPlayer.setUrl(track.source);
        await _audioPlayer.play();
        print('Audio player started successfully');
      }

      // Set up timer to stop after 6 seconds
      _playbackTimer = Timer(const Duration(seconds: 6), () async {
        print('6 seconds elapsed, stopping playback');
        await stop();
      });
    } catch (e, stackTrace) {
      print('Error playing track: $e');
      print('Stack trace: $stackTrace');
      _isPlaying = false;
    }
  }

  /// Play the next track in the pool (cycles through all tracks before repeating)
  /// Plays the current track, then advances to the next one for the next call
  Future<void> playNextTrack() async {
    if (_tracks.isEmpty) {
      print('No tracks available for playNextTrack');
      return;
    }

    // Reset index if it's out of bounds (e.g., if tracks were removed)
    if (_currentTrackIndex >= _tracks.length) {
      _currentTrackIndex = 0;
    }

    print('playNextTrack: Current index=$_currentTrackIndex, Total tracks=${_tracks.length}');
    print('playNextTrack: About to play track: ${currentTrack?.trackName} by ${currentTrack?.artistName}');

    // Play the current track first
    await playCurrentTrack();

    // Then advance to next track for next time
    _currentTrackIndex = (_currentTrackIndex + 1) % _tracks.length;
    print('playNextTrack: Advanced to index=$_currentTrackIndex for next press');
  }

  /// Stop the current playback
  Future<void> stop() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  /// Dispose the audio service
  void dispose() {
    stop();
    _playerStateSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _audioPlayer.dispose();
  }
}

