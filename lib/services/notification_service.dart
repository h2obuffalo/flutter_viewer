import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const String _seenChangesKey = 'notification.seen_changes';
  static const String _notificationTimestampsKey = 'notification.timestamps';
  static const int maxNotificationsPerHour = 5;
  static const int groupingThreshold = 5; // Group if >= 5 updates per artist

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    await _requestPermissions();

    _initialized = true;
  }

  /// Request notification permissions (Android 13+)
  Future<void> _requestPermissions() async {
    if (await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false) {
      print('Notification permissions granted');
    }
  }

  /// Check rate limiting - max 5 notifications per hour
  Future<bool> _checkRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampsStr = prefs.getStringList(_notificationTimestampsKey) ?? [];
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    // Filter out timestamps older than 1 hour
    final recentTimestamps = timestampsStr.map((ts) => DateTime.parse(ts))
        .where((ts) => ts.isAfter(oneHourAgo))
        .toList();
    
    if (recentTimestamps.length >= maxNotificationsPerHour) {
      print('⚠️ Rate limit reached: ${recentTimestamps.length} notifications in the last hour');
      return false;
    }
    
    return true;
  }
  
  /// Record notification timestamp for rate limiting
  Future<void> _recordNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampsStr = prefs.getStringList(_notificationTimestampsKey) ?? [];
    final now = DateTime.now().toIso8601String();
    timestampsStr.add(now);
    await prefs.setStringList(_notificationTimestampsKey, timestampsStr);
  }

  /// Show notification for lineup changes with smart grouping
  Future<void> showLineupChangeNotification({
    required List<Map<String, dynamic>> changes,
  }) async {
    if (!_initialized) await initialize();
    if (changes.isEmpty) return;

    // Check rate limiting
    if (!await _checkRateLimit()) {
      print('⚠️ Skipping notifications due to rate limit');
      // Still mark changes as seen so they don't show later
      final prefs = await SharedPreferences.getInstance();
      final seenChanges = prefs.getStringList(_seenChangesKey) ?? [];
      for (final change in changes) {
        final changeKey = '${change['type']}_${change['artistId']}_${change['ts']}';
        if (!seenChanges.contains(changeKey)) {
          seenChanges.add(changeKey);
        }
      }
      await prefs.setStringList(_seenChangesKey, seenChanges);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seenChanges = prefs.getStringList(_seenChangesKey) ?? [];
    
    // Filter out changes we've already notified about
    final newChanges = changes.where((change) {
      final changeKey = '${change['type']}_${change['artistId']}_${change['ts']}';
      return !seenChanges.contains(changeKey);
    }).toList();

    if (newChanges.isEmpty) return;

    // Group changes by artist ID
    final changesByArtist = <int, List<Map<String, dynamic>>>{};
    for (final change in newChanges) {
      final artistId = change['artistId'] as int;
      changesByArtist.putIfAbsent(artistId, () => []).add(change);
    }
    
    // If multiple artists changed, send one notification directing to updates page
    if (changesByArtist.length > 1) {
      final payload = {
        'type': 'multiple_artists',
        'artistIds': changesByArtist.keys.toList(),
        'redirect': 'updates',
      };
      
      const androidDetails = AndroidNotificationDetails(
        'lineup_updates',
        'Lineup Updates',
        channelDescription: 'Notifications when lineup schedules change',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        'Lineup Updates',
        '${changesByArtist.length} artists have schedule updates',
        notificationDetails,
        payload: jsonEncode(payload),
      );
      
      await _recordNotification();
      
      // Mark all changes as seen
      for (final change in newChanges) {
        final changeKey = '${change['type']}_${change['artistId']}_${change['ts']}';
        seenChanges.add(changeKey);
      }
      await prefs.setStringList(_seenChangesKey, seenChanges);
      return;
    }

    // Single artist - check if we should group notifications
    final singleArtistId = changesByArtist.keys.first;
    final artistChanges = changesByArtist[singleArtistId]!;
    
    // Count set time and stage changes (these are the updates)
    final updateChanges = artistChanges.where((c) => 
      c['type'] == 'settime-change' || c['type'] == 'stage-change'
    ).toList();
    
    if (updateChanges.length >= groupingThreshold) {
      // 5+ updates - send one combined notification
      await _showCombinedArtistNotification(singleArtistId, artistChanges);
      await _recordNotification();
      
      // Mark all changes as seen
      for (final change in artistChanges) {
        final changeKey = '${change['type']}_${change['artistId']}_${change['ts']}';
        seenChanges.add(changeKey);
      }
    } else {
      // < 5 updates - send individual notifications
      for (var i = 0; i < artistChanges.length; i++) {
        final change = artistChanges[i];
        final changeKey = '${change['type']}_${change['artistId']}_${change['ts']}';
        seenChanges.add(changeKey);
        
        await _showSingleChangeNotification(change);
        await _recordNotification();
        
        // Small delay between notifications so they don't overlap
        if (i < artistChanges.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    
    await prefs.setStringList(_seenChangesKey, seenChanges);
  }

  /// Show a combined notification for an artist with many updates
  Future<void> _showCombinedArtistNotification(
    int artistId,
    List<Map<String, dynamic>> changes,
  ) async {
    final artistName = changes.first['artist'] ?? 'An artist';
    
    // Count updates by type
    final setTimeCount = changes.where((c) => c['type'] == 'settime-change').length;
    final stageCount = changes.where((c) => c['type'] == 'stage-change').length;
    final totalUpdates = setTimeCount + stageCount;
    
    String title = 'Multiple Updates: $artistName';
    String body = '$totalUpdates updates: ';
    final parts = <String>[];
    if (setTimeCount > 0) parts.add('$setTimeCount set time${setTimeCount > 1 ? 's' : ''}');
    if (stageCount > 0) parts.add('$stageCount stage change${stageCount > 1 ? 's' : ''}');
    body += parts.join(', ');
    body += '\n\nTap to view details in Updates.';

    final payload = {
      'type': 'single_artist',
      'artistId': artistId,
      'redirect': 'updates', // Redirect to updates page
    };

    final androidDetails = AndroidNotificationDetails(
      'lineup_updates',
      'Lineup Updates',
      channelDescription: 'Notifications when lineup schedules change',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(payload),
    );
  }

  /// Show a single change notification
  Future<void> _showSingleChangeNotification(Map<String, dynamic> change) async {
    final artistName = change['artist'] ?? 'An artist';
    String title;
    String body;

    if (change['type'] == 'settime-change') {
        title = 'Schedule Update: $artistName';
        
        // Format set time details
        final from = change['from'] as List<dynamic>? ?? [];
        final to = change['to'] as List<dynamic>? ?? [];
        
        // Extract new set times
        final newSetTimes = to.map((st) {
          if (st is Map) {
            final start = st['start'] as String? ?? '';
            final end = st['end'] as String? ?? '';
            final stage = st['stage'] as String? ?? '';
            final status = st['status'] as String? ?? '';
            
            // Format time nicely
            try {
              final startDt = DateTime.parse(start);
              final endDt = DateTime.parse(end);
              final day = _getDayName(startDt.weekday);
              final startTime = '${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}';
              final endTime = '${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}';
              
              if (status == 'live') {
                return '$day $startTime-$endTime on $stage (LIVE)';
              } else {
                return '$day $startTime-$endTime on $stage';
              }
            } catch (_) {
              return '$start-$end on $stage';
            }
          }
          return '';
        }).where((s) => s.isNotEmpty).toList();
        
        if (newSetTimes.isNotEmpty) {
          if (newSetTimes.length == 1) {
            body = 'New time: ${newSetTimes[0]}';
          } else {
            body = '${newSetTimes.length} new set times added';
            if (newSetTimes.length <= 3) {
              body = 'New times:\n${newSetTimes.join('\n')}';
            }
          }
        } else {
          body = 'Schedule updated';
        }
      } else if (change['type'] == 'stage-change') {
        title = 'Stage Update: $artistName';
        
        final from = (change['from'] as List<dynamic>?)?.cast<String>() ?? <String>[];
        final to = (change['to'] as List<dynamic>?)?.cast<String>() ?? <String>[];
        
        if (to.isEmpty) {
          body = 'Stage information removed';
        } else if (to.length == 1) {
          body = 'Now playing on ${to[0]}';
        } else {
          body = 'Now playing on: ${to.join(', ')}';
        }
      } else if (change['type'] == 'artist-new') {
        title = 'New Artist: $artistName';
        body = 'Added to lineup';
      } else if (change['type'] == 'custom-message') {
        title = change['title'] ?? 'Festival Update';
        body = change['message'] ?? 'Update posted';
      } else {
        title = 'Lineup Update: $artistName';
        body = 'Information updated';
      }
      
      final payload = {
        'type': 'single_artist',
        'artistId': change['artistId'],
      };

      final androidDetails = AndroidNotificationDetails(
        'lineup_updates',
        'Lineup Updates',
        channelDescription: 'Notifications when lineup schedules change',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        styleInformation: BigTextStyleInformation(body),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a unique ID for each notification so they appear separately
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(payload),
      );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  /// Handle notification tap (called when user taps notification)
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
      
      // Store navigation info for app to handle
      // This works whether app is in foreground, background, or terminated
      _handleNotificationPayload(payload);
    } catch (e) {
      print('Error parsing notification payload: $e');
    }
  }

  /// Store notification payload for navigation
  Future<void> _handleNotificationPayload(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification', jsonEncode(payload));
  }

  /// Get pending notification navigation (call from app to navigate)
  Future<Map<String, dynamic>?> getPendingNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('pending_notification');
    if (pending != null) {
      await prefs.remove('pending_notification');
      return jsonDecode(pending) as Map<String, dynamic>;
    }
    return null;
  }
}

