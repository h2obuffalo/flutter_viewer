import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/artist.dart';

class NowPlayingService {
  static List<Artist> _artists = [];
  
  static Future<void> loadArtists() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/lineup-2025.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> artistsJson = jsonData['artists'] ?? [];
      
      _artists = artistsJson.map((json) => Artist.fromJson(json)).toList();
    } catch (e) {
      print('Error loading artists: $e');
      _artists = [];
    }
  }
  
  static List<Artist> getNowPlayingAndUpcoming() {
    final now = DateTime.now();
    final oneHourFromNow = now.add(const Duration(hours: 1));
    
    return _artists.where((artist) {
      return artist.setTimes.any((setTime) {
        final startTime = DateTime.parse(setTime.start);
        final endTime = DateTime.parse(setTime.end);
        
        // Check if the set time overlaps with "now" to "now + 1 hour"
        return (startTime.isBefore(oneHourFromNow) && endTime.isAfter(now));
      });
    }).toList();
  }
  
  static bool hasScheduledContent() {
    return getNowPlayingAndUpcoming().isNotEmpty;
  }
  
  static List<Artist> getNowPlaying() {
    final now = DateTime.now();
    
    return _artists.where((artist) {
      return artist.setTimes.any((setTime) {
        final startTime = DateTime.parse(setTime.start);
        final endTime = DateTime.parse(setTime.end);
        
        // Check if currently playing (started and not ended)
        return startTime.isBefore(now) && endTime.isAfter(now);
      });
    }).toList();
  }
  
  static List<Artist> getUpcoming() {
    final now = DateTime.now();
    final oneHourFromNow = now.add(const Duration(hours: 1));
    
    return _artists.where((artist) {
      return artist.setTimes.any((setTime) {
        final startTime = DateTime.parse(setTime.start);
        
        // Check if starting within the next hour
        return startTime.isAfter(now) && startTime.isBefore(oneHourFromNow);
      });
    }).toList();
  }
}
