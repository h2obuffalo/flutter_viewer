import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/remote_lineup_sync_service.dart';
import '../services/notification_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _updates = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _refreshController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadUpdates();
    // Mark all updates as seen when screen is opened
    NotificationService().markAllUpdatesAsSeen();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadUpdates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updates = await RemoteLineupSyncService().getNewsLog(limit: 200);
      setState(() {
        _updates = updates;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        // Error loading updates
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String? ts) {
    if (ts == null) return 'Just now';
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('MMM d, y').format(dt);
      }
    } catch (_) {
      return 'Just now';
    }
  }

  String _formatSetTime(Map<String, dynamic> setTime) {
    try {
      final start = setTime['start'] as String? ?? '';
      final end = setTime['end'] as String? ?? '';
      final stage = setTime['stage'] as String? ?? '';
      final status = setTime['status'] as String? ?? '';

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
      return '${setTime['start']}-${setTime['end']} on ${setTime['stage']}';
    }
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

  Widget _buildUpdateCard(Map<String, dynamic> update) {
    final type = update['type'] as String? ?? 'unknown';
    final timestamp = update['ts'] as String?;
    final artistName = update['artist'] as String?;

    Color cardColor;
    Color borderColor;
    IconData icon;

    switch (type) {
      case 'settime-change':
        cardColor = RetroTheme.neonCyan.withValues(alpha: 0.1);
        borderColor = RetroTheme.neonCyan;
        icon = Icons.schedule;
        break;
      case 'stage-change':
        cardColor = RetroTheme.hotPink.withValues(alpha: 0.1);
        borderColor = RetroTheme.hotPink;
        icon = Icons.location_on;
        break;
      case 'artist-new':
        cardColor = RetroTheme.electricGreen.withValues(alpha: 0.1);
        borderColor = RetroTheme.electricGreen;
        icon = Icons.person_add;
        break;
      case 'custom-message':
        cardColor = Colors.black.withValues(alpha: 0.95);
        borderColor = Colors.white;
        icon = Icons.announcement; // Will be replaced with GIF in UI
        break;
      default:
        cardColor = RetroTheme.darkGray.withValues(alpha: 0.1);
        borderColor = RetroTheme.darkGray;
        icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: type == 'custom-message' 
          ? Border.all(color: borderColor, width: 0) // No border for custom messages
          : Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon, title, and timestamp
            Row(
              children: [
                if (type == 'custom-message')
                  Image.asset(
                    'assets/images/bangface.gif',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  )
                else
                  Icon(icon, color: borderColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (artistName != null)
                        Text(
                          artistName,
                          style: TextStyle(
                            color: type == 'custom-message' ? Colors.white : borderColor,
                            fontSize: 18,
                            fontWeight: type == 'custom-message' ? FontWeight.normal : FontWeight.bold,
                            fontFamily: type == 'custom-message' ? 'Impact' : 'Verdana',
                          ),
                        ),
                      if (type == 'custom-message')
                        Text(
                          update['title'] ?? 'BANG FACE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Impact',
                          ),
                        ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          color: type == 'custom-message' ? Colors.white70 : RetroTheme.mutedGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            if (type == 'settime-change') ..._buildSetTimeContent(update),
            if (type == 'stage-change') ..._buildStageContent(update),
            if (type == 'artist-new') ..._buildNewArtistContent(update),
            if (type == 'custom-message') ..._buildCustomMessageContent(update),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSetTimeContent(Map<String, dynamic> update) {
    final to = update['to'] as List<dynamic>? ?? [];
    final newSetTimes = to.map((st) {
      if (st is Map<String, dynamic>) {
        return _formatSetTime(st);
      }
      return '';
    }).where((s) => s.isNotEmpty).toList();

    if (newSetTimes.isEmpty) {
      return [
        Text(
          'Schedule updated',
          style: TextStyle(
            color: RetroTheme.neonCyan,
            fontSize: 14,
            fontFamily: 'Verdana',
          ),
        ),
      ];
    }

    return [
                      Text(
                        'Updated set times:',
                        style: TextStyle(
                          color: RetroTheme.neonCyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...newSetTimes.map((time) => Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 4),
                            child: Text(
                              '• $time',
                              style: TextStyle(
                                color: RetroTheme.neonCyan,
                                fontSize: 14,
                                fontFamily: 'Verdana',
                              ),
                            ),
                          )),
    ];
  }

  List<Widget> _buildStageContent(Map<String, dynamic> update) {
    final to = (update['to'] as List<dynamic>?)?.cast<String>() ?? <String>[];

    if (to.isEmpty) {
      return [
        Text(
          'Stage information removed',
          style: TextStyle(
            color: RetroTheme.hotPink,
            fontSize: 14,
            fontFamily: 'Verdana',
          ),
        ),
      ];
    }

    return [
      Text(
        'Now playing on:',
        style: TextStyle(
          color: RetroTheme.hotPink,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      ...to.map((stage) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '• $stage',
              style: TextStyle(
                color: RetroTheme.hotPink,
                fontSize: 14,
                fontFamily: 'Verdana',
              ),
            ),
          )),
    ];
  }

  List<Widget> _buildNewArtistContent(Map<String, dynamic> update) {
    return [
      Text(
        'New artist added to lineup!',
        style: TextStyle(
          color: RetroTheme.electricGreen,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Verdana',
        ),
      ),
    ];
  }

  List<Widget> _buildCustomMessageContent(Map<String, dynamic> update) {
    final message = update['message'] as String? ?? '';
    
    return [
      MarkdownBody(
        data: message,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontFamily: 'Verdana'),
          strong: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Verdana'),
          em: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontFamily: 'Verdana'),
          a: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontFamily: 'Verdana'),
          h1: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Verdana'),
          h2: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Verdana'),
          h3: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Verdana'),
          code: TextStyle(color: Colors.white, fontFamily: 'monospace'),
          codeblockDecoration: BoxDecoration(
            color: RetroTheme.darkBlue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: RetroTheme.darkBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: RetroTheme.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BFTV',
              style: TextStyle(
                color: RetroTheme.neonCyan,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Impact',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'notifications',
              style: TextStyle(
                color: RetroTheme.neonCyan,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Verdana',
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh updates',
            icon: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_refreshController),
              child: const Icon(Icons.refresh, color: RetroTheme.neonCyan),
            ),
            onPressed: _isRefreshing ? null : () async {
              HapticFeedback.mediumImpact();
              setState(() {
                _isRefreshing = true;
              });
              _refreshController.repeat();
              
              try {
                // Fetch updates from API
                await RemoteLineupSyncService().refreshIfChanged(sendNotifications: false);
                await _loadUpdates();
              } finally {
                if (mounted) {
                  setState(() {
                    _isRefreshing = false;
                  });
                  _refreshController.stop();
                  _refreshController.reset();
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUpdates,
        color: RetroTheme.neonCyan,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: RetroTheme.neonCyan,
                ),
              )
            : _updates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.update,
                          size: 64,
                          color: RetroTheme.mutedGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No updates yet',
                          style: TextStyle(
                            color: RetroTheme.mutedGray,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _updates.length,
                    itemBuilder: (context, index) {
                      return _buildUpdateCard(_updates[index]);
                    },
                  ),
      ),
    );
  }
}

