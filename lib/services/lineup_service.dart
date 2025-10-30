import 'dart:convert';
import 'package:flutter/services.dart';
import 'remote_lineup_sync_service.dart';
import '../models/artist.dart';

class LineupService {
  static final LineupService _instance = LineupService._internal();
  factory LineupService() => _instance;
  LineupService._internal();

  List<Artist>? _artists;
  bool _isLoading = false;

  // Get all artists (prefers remote cache, falls back to asset)
  Future<List<Artist>> getAllArtists() async {
    if (_artists != null) return _artists!;
    if (_isLoading) {
      // Wait for loading to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _artists ?? [];
    }
    
    // Try remote cached first
    final remote = await RemoteLineupSyncService().getCurrentArtists();
    if (remote.isNotEmpty) {
      _artists = remote;
      // Kick off an async refresh check (non-blocking)
      // ignore: unawaited_futures
      RemoteLineupSyncService().refreshIfChanged().then((changed) async {
        if (changed) {
          _artists = await RemoteLineupSyncService().getCurrentArtists();
        }
      });
      return _artists!;
    }

    return await _loadArtists();
  }

  // Load artists from JSON asset
  Future<List<Artist>> _loadArtists() async {
    if (_isLoading) return _artists ?? [];
    
    _isLoading = true;
    try {
      final String jsonString = await rootBundle.loadString('assets/lineup-2025.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _artists = jsonList.map((json) => Artist.fromJson(json as Map<String, dynamic>)).toList();
      return _artists!;
    } catch (e) {
      print('Error loading lineup data: $e');
      return [];
    } finally {
      _isLoading = false;
    }
  }

  // Get artists by stage
  Future<List<Artist>> getArtistsByStage(String stage) async {
    final allArtists = await getAllArtists();
    return allArtists.where((artist) => artist.stages.contains(stage)).toList();
  }

  // Search artists by name
  Future<List<Artist>> searchArtists(String query) async {
    if (query.isEmpty) return await getAllArtists();
    
    final allArtists = await getAllArtists();
    final lowercaseQuery = query.toLowerCase();
    
    return allArtists.where((artist) {
      return artist.name.toLowerCase().contains(lowercaseQuery) ||
             artist.stages.any((stage) => stage.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // Get currently playing artists
  Future<List<Artist>> getCurrentlyPlaying() async {
    final allArtists = await getAllArtists();
    return allArtists.where((artist) => artist.isCurrentlyPlaying).toList();
  }

  // Get upcoming artists (next 5)
  Future<List<Artist>> getUpcoming({int limit = 5}) async {
    final allArtists = await getAllArtists();
    final upcomingArtists = <Artist>[];
    
    for (final artist in allArtists) {
      if (artist.hasUpcomingSets) {
        upcomingArtists.add(artist);
      }
    }
    
    // Sort by next set time
    upcomingArtists.sort((a, b) {
      final aNext = a.nextSet;
      final bNext = b.nextSet;
      
      if (aNext == null && bNext == null) return 0;
      if (aNext == null) return 1;
      if (bNext == null) return -1;
      
      return aNext.startDateTime.compareTo(bNext.startDateTime);
    });
    
    return upcomingArtists.take(limit).toList();
  }

  // Get artists by stage with current/upcoming status
  Future<List<Artist>> getArtistsByStageWithStatus(String stage) async {
    final stageArtists = await getArtistsByStage(stage);
    
    // Sort by status: currently playing first, then upcoming, then others
    stageArtists.sort((a, b) {
      if (a.isCurrentlyPlaying && !b.isCurrentlyPlaying) return -1;
      if (!a.isCurrentlyPlaying && b.isCurrentlyPlaying) return 1;
      if (a.hasUpcomingSets && !b.hasUpcomingSets) return -1;
      if (!a.hasUpcomingSets && b.hasUpcomingSets) return 1;
      return a.name.compareTo(b.name);
    });
    
    return stageArtists;
  }

  // Get all unique stages
  Future<List<String>> getAllStages() async {
    final allArtists = await getAllArtists();
    final stages = <String>{};
    
    for (final artist in allArtists) {
      stages.addAll(artist.stages);
    }
    
    return stages.toList()..sort();
  }

  // Get artist by ID
  Future<Artist?> getArtistById(int id) async {
    final allArtists = await getAllArtists();
    try {
      return allArtists.firstWhere((artist) => artist.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get artists with links (website or bandcamp)
  Future<List<Artist>> getArtistsWithLinks() async {
    final allArtists = await getAllArtists();
    return allArtists.where((artist) => artist.hasLinks).toList();
  }

  // Clear cache (useful for testing or if data needs to be reloaded)
  void clearCache() {
    _artists = null;
    _isLoading = false;
  }

  // Get statistics
  Future<Map<String, int>> getStatistics() async {
    final allArtists = await getAllArtists();
    final stages = await getAllStages();
    
    return {
      'totalArtists': allArtists.length,
      'totalStages': stages.length,
      'artistsWithLinks': (await getArtistsWithLinks()).length,
      'currentlyPlaying': (await getCurrentlyPlaying()).length,
      'upcoming': (await getUpcoming()).length,
    };
  }
}
