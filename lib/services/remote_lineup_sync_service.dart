import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist.dart';

class RemoteLineupSyncService with ChangeNotifier {
  static final RemoteLineupSyncService _instance = RemoteLineupSyncService._internal();
  factory RemoteLineupSyncService() => _instance;
  RemoteLineupSyncService._internal();

  static const String _prefsUrlKey = 'lineup.remote.url';
  static const String _prefsJsonKey = 'lineup.remote.json';
  static const String _prefsEtagKey = 'lineup.remote.etag';
  static const String _prefsLastModifiedKey = 'lineup.remote.lastModified';
  static const String _prefsNewsKey = 'lineup.news.log';

  String? _lineupUrlOverride;
  List<Artist>? _cachedArtists;

  Future<void> setLineupUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    _lineupUrlOverride = url?.trim().isEmpty == true ? null : url?.trim();
    if (_lineupUrlOverride == null) {
      await prefs.remove(_prefsUrlKey);
    } else {
      await prefs.setString(_prefsUrlKey, _lineupUrlOverride!);
    }
  }

  Future<String?> getLineupUrl() async {
    if (_lineupUrlOverride != null) return _lineupUrlOverride;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsUrlKey);
  }

  Future<List<Artist>> getCurrentArtists() async {
    if (_cachedArtists != null) return _cachedArtists!;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsJsonKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
        _cachedArtists = list.map((e) => Artist.fromJson(e)).toList();
        return _cachedArtists!;
      } catch (_) {}
    }
    // Fallback to bundled asset
    final bundled = await rootBundle.loadString('assets/lineup-2025.json');
    final list = (jsonDecode(bundled) as List).cast<Map<String, dynamic>>();
    _cachedArtists = list.map((e) => Artist.fromJson(e)).toList();
    return _cachedArtists!;
  }

  Future<bool> refreshIfChanged() async {
    final url = await getLineupUrl();
    if (url == null || url.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final etag = prefs.getString(_prefsEtagKey);
    final lastMod = prefs.getString(_prefsLastModifiedKey);

    final headers = <String, String>{};
    if (etag != null) headers['If-None-Match'] = etag;
    if (lastMod != null) headers['If-Modified-Since'] = lastMod;

    try {
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 304) {
        return false; // unchanged
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final newJson = resp.body;
        final newArtists = (jsonDecode(newJson) as List).map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();

        final oldArtists = await getCurrentArtists();
        final changes = _diffLineup(oldArtists, newArtists);
        if (changes.isNotEmpty) {
          await _appendNews(changes);
        }

        await prefs.setString(_prefsJsonKey, newJson);
        final newEtag = resp.headers['etag'];
        final newLastMod = resp.headers['last-modified'];
        if (newEtag != null) await prefs.setString(_prefsEtagKey, newEtag);
        if (newLastMod != null) await prefs.setString(_prefsLastModifiedKey, newLastMod);

        _cachedArtists = newArtists;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  List<Map<String, dynamic>> _diffLineup(List<Artist> oldA, List<Artist> newA) {
    final byIdOld = { for (final a in oldA) a.id: a };
    final byIdNew = { for (final a in newA) a.id: a };
    final changes = <Map<String, dynamic>>[];

    // Detect set time / stage changes only (ignore bio/typos for notifications)
    for (final id in {...byIdOld.keys, ...byIdNew.keys}) {
      final o = byIdOld[id];
      final n = byIdNew[id];
      if (o == null || n == null) continue; // creation/deletion ignored for now

      // Stage changes
      final oStages = {...o.stages};
      final nStages = {...n.stages};
      if (listEquals(o.stages, n.stages) == false) {
        changes.add({
          'type': 'stage-change',
          'artistId': id,
          'artist': n.name,
          'from': oStages.toList(),
          'to': nStages.toList(),
          'ts': DateTime.now().toIso8601String(),
        });
      }

      // Set time changes (naive compare by stringified lists)
      final oSets = o.setTimes.map((s) => s.toJson()).toList();
      final nSets = n.setTimes.map((s) => s.toJson()).toList();
      if (!listEquals(oSets, nSets)) {
        changes.add({
          'type': 'settime-change',
          'artistId': id,
          'artist': n.name,
          'from': oSets,
          'to': nSets,
          'ts': DateTime.now().toIso8601String(),
        });
      }
    }
    return changes;
  }

  Future<void> _appendNews(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsNewsKey);
    final list = existing != null ? (jsonDecode(existing) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    list.insertAll(0, items);
    await prefs.setString(_prefsNewsKey, jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> getNewsLog({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsNewsKey);
    if (existing == null) return [];
    final list = (jsonDecode(existing) as List).cast<Map<String, dynamic>>();
    return list.take(limit).toList();
  }
}


