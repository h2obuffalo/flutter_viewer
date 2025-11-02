import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist.dart';
import '../config/constants.dart';
import 'notification_service.dart';

class RemoteLineupSyncService with ChangeNotifier {
  static final RemoteLineupSyncService _instance = RemoteLineupSyncService._internal();
  factory RemoteLineupSyncService() => _instance;
  RemoteLineupSyncService._internal();

  static const String _prefsUrlKey = 'lineup.remote.url';
  static const String _prefsJsonKey = 'lineup.remote.json';
  static const String _prefsEtagKey = 'lineup.remote.etag';
  static const String _prefsLastModifiedKey = 'lineup.remote.lastModified';
  static const String _prefsNewsKey = 'lineup.news.log';
  static const String _prefsKnownArtistIdsKey = 'lineup.known.artist.ids';
  static const String _prefsBundledJsonKey = 'lineup.bundled.json';
  static const String _prefsUpdatedSetTimesKey = 'lineup.updated.set.times';
  static const String _prefsFirstLoadTimestampKey = 'lineup.first.load.timestamp';
  static const String _prefsBaselineEstablishedKey = 'lineup.baseline.established';

  String? _lineupUrlOverride;
  List<Artist>? _cachedArtists;

  /// Check if we have cached lineup data available (either API cache or bundled asset)
  Future<bool> hasCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsJsonKey);
    // If we have API cached data, we definitely have something
    if (cached != null && cached.isNotEmpty) {
      return true;
    }
    // If we have bundled JSON cached, we also have something
    final bundledCached = prefs.getString(_prefsBundledJsonKey);
    if (bundledCached != null && bundledCached.isNotEmpty) {
      return true;
    }
    // We always have the bundled asset file, so we can consider it "cached"
    return true; // Bundled asset is always available
  }

  /// Preload lineup data in background if cached data exists
  /// This makes the lineup screen load instantly when opened
  Future<void> preloadIfCached() async {
    if (_cachedArtists != null) {
      return; // Already loaded
    }
    try {
      // This will load from cache first, then bundled asset if no cache
      await getCurrentArtists();
      print('✅ Preloaded lineup data in background');
    } catch (e) {
      print('⚠️ Failed to preload lineup data: $e');
    }
  }

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
    final cached = prefs.getString(_prefsUrlKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    // Default to lineup API endpoint
    return AppConstants.lineupJsonUrl;
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
    
    // Load bundled asset immediately (for offline use and instant display)
    List<Artist>? bundledArtists;
    try {
      // Try stored bundled JSON first (updated from API), then fall back to actual bundled asset
      final storedBundled = prefs.getString(_prefsBundledJsonKey);
      if (storedBundled != null && storedBundled.isNotEmpty) {
        final list = (jsonDecode(storedBundled) as List).cast<Map<String, dynamic>>();
        bundledArtists = list.map((e) => Artist.fromJson(e)).toList();
      } else {
        // Fallback to actual bundled asset
        final bundled = await rootBundle.loadString('assets/lineup-2025.json');
        final list = (jsonDecode(bundled) as List).cast<Map<String, dynamic>>();
        bundledArtists = list.map((e) => Artist.fromJson(e)).toList();
      }
      
      // Return bundled asset immediately so UI isn't blocked
      _cachedArtists = bundledArtists;
      
      // Then try to fetch from API in background and update if successful
      final url = await getLineupUrl();
      if (url != null && url.isNotEmpty) {
        // Don't await - fetch in background
        http.get(Uri.parse(url)).timeout(const Duration(seconds: 8)).then((resp) async {
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final newJson = resp.body;
            final newArtists = (jsonDecode(newJson) as List).map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();
            
            // Cache it
            await prefs.setString(_prefsJsonKey, newJson);
            final newEtag = resp.headers['etag'];
            final newLastMod = resp.headers['last-modified'];
            if (newEtag != null) await prefs.setString(_prefsEtagKey, newEtag);
            if (newLastMod != null) await prefs.setString(_prefsLastModifiedKey, newLastMod);
            
            // Update bundled asset storage (for offline use)
            await prefs.setString(_prefsBundledJsonKey, newJson);
            
            // Store known artist IDs (for detecting new vs updated artists)
            final knownIds = newArtists.map((a) => a.id).toList();
            await prefs.setStringList(_prefsKnownArtistIdsKey, knownIds.map((id) => id.toString()).toList());
            
            // Update cached artists and notify listeners
            _cachedArtists = newArtists;
            notifyListeners();
          }
        }).catchError((_) {
          // API fetch failed (offline/timeout) - bundled asset already loaded, so that's fine
        });
      }
      
      return _cachedArtists!;
    } catch (e) {
      print('Error loading bundled asset: $e');
      return [];
    }
  }

  Future<bool> refreshIfChanged({bool sendNotifications = true}) async {
    print('🔄 refreshIfChanged called (sendNotifications: $sendNotifications)');
    final url = await getLineupUrl();
    if (url == null || url.isEmpty) {
      print('❌ No lineup URL configured');
      return false;
    }
    print('🔄 Fetching from URL: $url');

    final prefs = await SharedPreferences.getInstance();
    final etag = prefs.getString(_prefsEtagKey);
    final lastMod = prefs.getString(_prefsLastModifiedKey);
    print('🔄 Current ETag: $etag, LastMod: $lastMod');

    // Track if we've previously loaded from API (have ETag AND cached JSON from API)
    // AND have established a stable baseline (meaning we've had at least one successful
    // refresh cycle where we checked for changes)
    // This ensures we only show notifications for real changes, not initial loads
    final cachedJson = prefs.getString(_prefsJsonKey);
    final baselineEstablished = prefs.getBool(_prefsBaselineEstablishedKey) ?? false;
    
    // We need ALL of:
    // 1. Have cached data from API (ETag/LastMod + JSON)
    // 2. Have established baseline (meaning we've done at least one comparison cycle)
    // This prevents comparing first-load data to refresh data
    final hasPreviousApiLoad = (etag != null || lastMod != null) && 
                                cachedJson != null && 
                                cachedJson.isNotEmpty &&
                                baselineEstablished;

    final headers = <String, String>{};
    if (etag != null) headers['If-None-Match'] = etag;
    if (lastMod != null) headers['If-Modified-Since'] = lastMod;

    try {
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
      print('🔄 API Response: ${resp.statusCode}');
      if (resp.statusCode == 304) {
        print('✅ Server says unchanged (304) - data is up to date');
        return false; // unchanged
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final newJson = resp.body;
        final newEtag = resp.headers['etag'];
        final newLastMod = resp.headers['last-modified'];
        final newArtists = (jsonDecode(newJson) as List).map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();

        // Only check for changes and show notifications if:
        // 1. We have previous API data cached (not first load)
        // 2. Notifications are enabled (not called from screen init)
        // 3. ETag/Last-Modified indicates actual change (not 304)
        // 4. We actually got new data (status 200, not 304)
        // 5. ETags don't match (indicating data actually changed)
        // 6. Baseline is established OR we're doing a silent check (prevents mass notifications on first load)
        // Allow comparison if we have previous API data, even if baseline not yet established
        // (baseline will be established after this comparison)
        final baselineEstablished = prefs.getBool(_prefsBaselineEstablishedKey) ?? false;
        final shouldCompare = hasPreviousApiLoad && 
                               sendNotifications && 
                               resp.statusCode == 200 &&
                               (etag == null || newEtag == null || etag != newEtag);
                               // Removed baselineEstablished requirement - we'll establish it during comparison
                               // This allows first comparison after cache is populated
        
        print('🔍 shouldCompare check: hasPreviousApiLoad=$hasPreviousApiLoad, sendNotifications=$sendNotifications, statusCode=${resp.statusCode}, etagMatch=${etag != null && newEtag != null && etag == newEtag}');
        print('🔍 shouldCompare result: $shouldCompare');
        
        // Track if changes were detected (scope it outside the if block)
        List<Map<String, dynamic>>? detectedChanges;
        
        if (shouldCompare) {
          // Get the previously cached API data directly from SharedPreferences to ensure
          // we're comparing API data to API data, not bundled asset to API data
          final oldCachedJson = prefs.getString(_prefsJsonKey);
          if (oldCachedJson != null && oldCachedJson.isNotEmpty) {
            try {
              final oldJsonList = (jsonDecode(oldCachedJson) as List).cast<Map<String, dynamic>>();
              final oldArtists = oldJsonList.map((e) => Artist.fromJson(e)).toList();
              print('🔍 Comparing ${oldArtists.length} old artists vs ${newArtists.length} new artists');
              print('🔍 Old ETag: $etag, New ETag: ${resp.headers["etag"]}');
              print('🔍 Old LastMod: $lastMod, New LastMod: ${resp.headers["last-modified"]}');
              
              // Debug: Check Wavey G specifically
              final oldWavey = oldArtists.firstWhere((a) => a.id == 147, orElse: () => null as dynamic);
              final newWavey = newArtists.firstWhere((a) => a.id == 147, orElse: () => null as dynamic);
              if (oldWavey != null && newWavey != null) {
                print('🔍 Wavey G old set times: ${oldWavey.setTimes.map((st) => '${st.start}-${st.end}').join(", ")}');
                print('🔍 Wavey G new set times: ${newWavey.setTimes.map((st) => '${st.start}-${st.end}').join(", ")}');
              }
              
              // Quick check: if ETags match exactly, no changes
              // Note: newEtag is already defined above, reuse it
              final newEtagFromResp = resp.headers['etag'];
              print('🔍 ETag comparison: cached="$etag" vs new="$newEtagFromResp"');
              if (etag != null && newEtagFromResp != null && etag == newEtagFromResp) {
                print('✅ ETags match exactly - API returned identical data, skipping comparison');
                // Mark baseline as established (we've now done a comparison cycle)
                await prefs.setBool(_prefsBaselineEstablishedKey, true);
                // Still update cache but skip comparison
                // ETags match means data is identical, so detectedChanges stays null
              } else {
                print('🔍 ETags differ or missing - performing detailed comparison...');
                detectedChanges = await _diffLineup(oldArtists, newArtists);
                print('📊 Detected ${detectedChanges.length} changes: ${detectedChanges.map((c) => '${c["type"]} (${c["artist"]})').join(", ")}');
                
                // Safety check: if we detect too many changes, it's likely a false positive
                // (e.g., data format changed, JSON ordering, baseline not properly established, etc.)
                // Check both total changes count AND unique artists affected
                final uniqueArtistIds = detectedChanges.map((c) => c['artistId'] as int).toSet();
                
                // More aggressive threshold: if more than 5 unique artists changed,
                // it's likely a false positive (like first load or format change)
                final baselineEstablishedCheck = prefs.getBool(_prefsBaselineEstablishedKey) ?? false;
                
                // Debug: If many changes, show sample of what's different
                if (detectedChanges.length > 15) {
                  print('🔍 DEBUG: Many changes detected, checking sample differences...');
                  final sample = detectedChanges.take(3).toList();
                  for (final change in sample) {
                    if (change['type'] == 'settime-change') {
                      final oldSets = change['from'] as List;
                      final newSets = change['to'] as List;
                      print('🔍   ${change['artist']} (${change['artistId']}): old=${oldSets.length} setTimes, new=${newSets.length} setTimes');
                      if (oldSets.isNotEmpty && newSets.isNotEmpty) {
                        print('🔍     Old first: ${oldSets.first}');
                        print('🔍     New first: ${newSets.first}');
                      }
                    }
                  }
                }
                
                // Safety check: if too many changes, it's likely a false positive
                // If baseline not established and too many changes, skip notifications but still update data
                // If baseline established and too many changes, skip everything
                if (detectedChanges.length > 15 || uniqueArtistIds.length > 5) {
                  if (!baselineEstablishedCheck) {
                    print('⚠️ Baseline not established yet and ${detectedChanges.length} changes detected (${uniqueArtistIds.length} artists) - establishing baseline silently, skipping notifications');
                    // Still mark baseline as established and update cache, just don't notify
                    await prefs.setBool(_prefsBaselineEstablishedKey, true);
                    // Clear changes since we're ignoring them
                    detectedChanges = [];
                  } else {
                    print('⚠️ Too many changes detected (${detectedChanges.length} changes, ${uniqueArtistIds.length} artists) - likely false positive, skipping all updates');
                    // Don't store anything, don't notify - this is definitely a false positive
                    // Clear changes since we're ignoring them
                    detectedChanges = [];
                  }
                } else if (detectedChanges.isNotEmpty) {
                  await _appendNews(detectedChanges);
                  // Update known artist IDs with new artists
                  final knownIdsStr = prefs.getStringList(_prefsKnownArtistIdsKey) ?? [];
                  final knownIds = knownIdsStr.map((s) => int.parse(s)).toSet();
                  final updatedArtistIds = <int>{};
                  
                  for (final change in detectedChanges) {
                    final artistId = change['artistId'] as int;
                    updatedArtistIds.add(artistId);
                    
                    if (change['type'] == 'artist-new') {
                      knownIds.add(artistId);
                    }
                  }
                  await prefs.setStringList(_prefsKnownArtistIdsKey, knownIds.map((id) => id.toString()).toList());
                  
                  // Store updated artist IDs for visual indicators (replace list with only newly changed artists)
                  // This ensures we only show indicators for artists that changed in this update
                  const String updatedArtistsKey = 'lineup.updated.artists';
                  await prefs.setStringList(updatedArtistsKey, updatedArtistIds.map((id) => id.toString()).toList());
                  
                  // Show notification for lineup changes
                  await NotificationService().showLineupChangeNotification(changes: detectedChanges);
                }
                // Mark baseline as established after successful comparison (whether changes found or not)
                await prefs.setBool(_prefsBaselineEstablishedKey, true);
              }
              
              // Update bundled asset storage if API fetch was successful
              await prefs.setString(_prefsBundledJsonKey, newJson);
            } catch (e) {
              // If we can't parse old cache, skip comparison
              print('❌ Error comparing lineup: $e');
            }
          }
        }

        // Always update cache (even if we skip comparison)
        await prefs.setString(_prefsJsonKey, newJson);
        if (newEtag != null) await prefs.setString(_prefsEtagKey, newEtag);
        if (newLastMod != null) await prefs.setString(_prefsLastModifiedKey, newLastMod);

        // If baseline not established yet, establish it now (after successful fetch)
        // This means we've completed at least one refresh cycle
        if (!baselineEstablished) {
          await prefs.setBool(_prefsBaselineEstablishedKey, true);
          print('✅ Baseline established after first successful refresh');
        }

        // Update cached artists - this is the source of truth for getCurrentArtists()
        _cachedArtists = newArtists;
        
        // Notify listeners that data has changed
        notifyListeners();
        
        // Clear updated indicators when data is refreshed (so old indicators don't persist)
        // Only clear if this was a non-notification refresh OR if this is still the initial load phase
        // Don't clear if we just detected actual changes (those indicators should stay)
        // Check if changes were detected (from the shouldCompare block)
        final hadChanges = detectedChanges != null && detectedChanges.isNotEmpty;
        if ((!sendNotifications || !hasPreviousApiLoad) && !hadChanges) {
          // Only clear on initial load or non-notification refresh, AND only if no changes were detected
          const String updatedArtistsKey = 'lineup.updated.artists';
          await prefs.remove(updatedArtistsKey);
          await prefs.remove(_prefsUpdatedSetTimesKey);
          print('🧹 Cleared updated indicators (initial load or no notifications, no changes detected)');
        } else if (hadChanges) {
          print('✅ Keeping updated indicators (${detectedChanges.length} changes detected)');
        }
        
        notifyListeners();
        
        // Check for custom messages from API (do this on every refresh)
        try {
          await _checkForCustomMessages();
        } catch (e) {
          print('⚠️ Error checking for custom messages: $e');
        }
        
        // Return true only if actual changes were detected
        final changesDetected = hadChanges;
        print('🔄 Returning from refreshIfChanged: ${changesDetected ? "changes detected" : "no changes"}');
        return changesDetected;
      }
    } catch (_) {}
    return false;
  }

  /// Check for new custom messages from API
  Future<void> _checkForCustomMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = 'lineup.custom_messages.last_check';
      final lastCheckStr = prefs.getString(lastCheckKey);
      final since = lastCheckStr ?? DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      
      final url = Uri.parse('${AppConstants.lineupApiUrl}/lineup/admin/messages?since=$since&limit=10');
      final resp = await http.get(url);
      
      if (resp.statusCode == 200) {
        final messages = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
        
        if (messages.isNotEmpty) {
          print('📨 Found ${messages.length} new custom messages');
          for (final msg in messages) {
            await addCustomMessage(
              title: msg['title'] ?? 'Festival Update',
              message: msg['message'] ?? '',
              timestamp: msg['ts'] != null ? DateTime.parse(msg['ts']) : null,
            );
          }
          
          // Update last check time
          await prefs.setString(lastCheckKey, DateTime.now().toIso8601String());
        }
      }
    } catch (e) {
      print('⚠️ Error checking for custom messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _diffLineup(List<Artist> oldA, List<Artist> newA) async {
    final byIdOld = { for (final a in oldA) a.id: a };
    final byIdNew = { for (final a in newA) a.id: a };
    final changes = <Map<String, dynamic>>[];
    
    final prefs = await SharedPreferences.getInstance();
    final knownIdsStr = prefs.getStringList(_prefsKnownArtistIdsKey) ?? [];
    final knownIds = knownIdsStr.map((s) => int.parse(s)).toSet();

    // Detect new artists (not in known list)
    for (final id in byIdNew.keys) {
      if (!knownIds.contains(id)) {
        final n = byIdNew[id];
        if (n != null) {
          changes.add({
            'type': 'artist-new',
            'artistId': id,
            'artist': n.name,
            'ts': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Detect set time / stage changes for existing artists
    for (final id in {...byIdOld.keys, ...byIdNew.keys}) {
      final o = byIdOld[id];
      final n = byIdNew[id];
      if (o == null || n == null) continue; // Skip if artist doesn't exist in both

      // Stage changes
      final oStages = {...o.stages};
      final nStages = {...n.stages};
      if (listEquals(o.stages, n.stages) == false) {
        // Track which set times changed
        final updatedSetTimes = _findUpdatedSetTimes(o.setTimes, n.setTimes);
        changes.add({
          'type': 'stage-change',
          'artistId': id,
          'artist': n.name,
          'from': oStages.toList(),
          'to': nStages.toList(),
          'updatedSetTimes': updatedSetTimes,
          'ts': DateTime.now().toIso8601String(),
        });
      }

      // Set time changes (compare sorted lists to be order-independent)
      final oSets = o.setTimes.map((s) => s.toJson()).toList();
      final nSets = n.setTimes.map((s) => s.toJson()).toList();
      
      // Normalize JSON by removing any null fields and ensuring consistent field order
      final normalizeJson = (Map<String, dynamic> json) {
        final normalized = <String, dynamic>{};
        final keys = ['start', 'end', 'stage', 'status'];
        for (final key in keys) {
          if (json.containsKey(key)) {
            normalized[key] = json[key];
          }
        }
        return normalized;
      };
      
      final oSetsNormalized = oSets.map(normalizeJson).toList();
      final nSetsNormalized = nSets.map(normalizeJson).toList();
      
      // Sort both lists by start time for consistent comparison
      oSetsNormalized.sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));
      nSetsNormalized.sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));
      
      // Use JSON string comparison for reliable equality check
      // listEquals can fail due to object identity issues with Map comparisons
      final oldJsonStr = jsonEncode(oSetsNormalized);
      final newJsonStr = jsonEncode(nSetsNormalized);
      final listsEqual = oldJsonStr == newJsonStr;
      
      // Debug: If different, show what's different (only for first few artists to avoid spam)
      if (!listsEqual && id <= 3) {
        print('🔍 DEBUG Artist $id (${n.name}): setTimes differ');
        print('🔍   Old JSON: ${oldJsonStr.length} chars');
        print('🔍   New JSON: ${newJsonStr.length} chars');
        if (oldJsonStr.length == newJsonStr.length && oldJsonStr != newJsonStr) {
          // Find first difference
          for (int i = 0; i < oldJsonStr.length && i < newJsonStr.length; i++) {
            if (oldJsonStr[i] != newJsonStr[i]) {
              print('🔍   First diff at char $i: old="${oldJsonStr.substring(i, (i+50).clamp(0, oldJsonStr.length))}" vs new="${newJsonStr.substring(i, (i+50).clamp(0, newJsonStr.length))}"');
              break;
            }
          }
        }
      }
      
      if (!listsEqual) {
        // Track which specific set times changed
        final updatedSetTimes = _findUpdatedSetTimes(o.setTimes, n.setTimes);
        changes.add({
          'type': 'settime-change',
          'artistId': id,
          'artist': n.name,
          'from': oSets,
          'to': nSets,
          'updatedSetTimes': updatedSetTimes,
          'ts': DateTime.now().toIso8601String(),
        });
        
        // Store updated set times for this artist
        print('💾 Storing ${updatedSetTimes.length} updated set times for artist $id (${n.name})');
        await _storeUpdatedSetTimes(id, updatedSetTimes);
      }
    }
    return changes;
  }
  
  List<Map<String, dynamic>> _findUpdatedSetTimes(List<SetTime> oldSets, List<SetTime> newSets) {
    // Create a signature for each set time (start, end, stage, status) to detect changes
    final updated = <Map<String, dynamic>>[];
    final oldSignatures = <String>{};
    final newSignatures = <String>{};
    
    // Build signature map for old sets (signature -> setTime JSON)
    final oldMap = <String, Map<String, dynamic>>{};
    for (final st in oldSets) {
      final sig = '${st.start}_${st.end}_${st.stage}_${st.status}';
      oldSignatures.add(sig);
      oldMap[sig] = st.toJson();
    }
    
    // Check new sets - if signature doesn't exist in old, it's new/updated
    for (final st in newSets) {
      final sig = '${st.start}_${st.end}_${st.stage}_${st.status}';
      newSignatures.add(sig);
      // If this signature wasn't in old sets, it's a new/updated set time
      if (!oldSignatures.contains(sig)) {
        updated.add(st.toJson());
      }
    }
    
    // Also check for removed set times (present in old but not in new)
    for (final sig in oldSignatures) {
      if (!newSignatures.contains(sig)) {
        // This set time was removed, include it in updates
        updated.add(oldMap[sig]!);
      }
    }
    
    return updated;
  }
  
  Future<void> _storeUpdatedSetTimes(int artistId, List<Map<String, dynamic>> updatedSetTimes) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsUpdatedSetTimesKey);
    final map = existing != null ? (jsonDecode(existing) as Map<String, dynamic>).cast<String, dynamic>() : <String, dynamic>{};
    
    // Store updated set times keyed by artist ID
    map[artistId.toString()] = updatedSetTimes;
    
    await prefs.setString(_prefsUpdatedSetTimesKey, jsonEncode(map));
  }
  
  Future<List<Map<String, dynamic>>> getUpdatedSetTimes(int artistId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsUpdatedSetTimesKey);
    if (existing == null) return [];
    
    final map = (jsonDecode(existing) as Map<String, dynamic>).cast<String, dynamic>();
    final artistData = map[artistId.toString()];
    if (artistData == null) return [];
    
    return (artistData as List).cast<Map<String, dynamic>>();
  }
  
  Future<void> clearUpdatedSetTimes(int artistId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsUpdatedSetTimesKey);
    if (existing == null) return;
    
    final map = (jsonDecode(existing) as Map<String, dynamic>).cast<String, dynamic>();
    map.remove(artistId.toString());
    
    await prefs.setString(_prefsUpdatedSetTimesKey, jsonEncode(map));
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
  
  // Clear the in-memory cache (forces next getCurrentArtists() to reload from SharedPreferences or fetch fresh)
  void clearCache() {
    _cachedArtists = null;
  }

  /// Add a custom message to the news log (for admin messages)
  Future<void> addCustomMessage({
    required String title,
    required String message,
    DateTime? timestamp,
  }) async {
    final customUpdate = {
      'type': 'custom-message',
      'title': title,
      'message': message,
      'ts': (timestamp ?? DateTime.now()).toIso8601String(),
      'artistId': 0, // Custom messages don't have an artist
      'artist': 'Festival Admin',
    };
    await _appendNews([customUpdate]);
    
    // Also trigger notification if rate limit allows
    try {
      await NotificationService().showLineupChangeNotification(changes: [customUpdate]);
    } catch (e) {
      print('⚠️ Could not send notification for custom message: $e');
    }
  }

  /// Fetch custom message from API and add to news log
  Future<void> fetchAndStoreCustomMessage(String apiUrl) async {
    try {
      final resp = await http.get(Uri.parse(apiUrl));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        await addCustomMessage(
          title: data['title'] ?? 'Festival Update',
          message: data['message'] ?? '',
          timestamp: data['ts'] != null ? DateTime.parse(data['ts']) : null,
        );
      }
    } catch (e) {
      print('⚠️ Error fetching custom message: $e');
    }
  }
}



