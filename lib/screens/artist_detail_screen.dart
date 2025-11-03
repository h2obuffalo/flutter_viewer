import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../models/artist.dart';
import '../services/remote_lineup_sync_service.dart';
import '../services/favorites_service.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> with TickerProviderStateMixin {
  Set<String> _updatedSetTimeSignatures = {};
  bool _isLoadingUpdatedSetTimes = true;
  late AnimationController _glitchController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUpdatedSetTimes();
    _loadFavoriteStatus();
  }
  
  Future<void> _loadFavoriteStatus() async {
    final favoriteIds = await FavoritesService.getFavoriteIds();
    setState(() {
      _isFavorited = favoriteIds.contains(widget.artist.id);
    });
  }
  
  Future<void> _loadUpdatedSetTimes() async {
    final updatedSetTimes = await RemoteLineupSyncService().getUpdatedSetTimes(widget.artist.id);
    print('🎨 Loading updated set times for artist ${widget.artist.id}: ${updatedSetTimes.length} found');
    
    // Create signatures for updated set times (start_end_stage_status) - must match service format
    final signatures = updatedSetTimes.map((st) {
      final start = st['start'] as String? ?? '';
      final end = st['end'] as String? ?? '';
      final stage = st['stage'] as String? ?? '';
      final status = st['status'] as String? ?? '';
      final sig = '${start}_${end}_${stage}_${status}';
      print('   Signature: $sig');
      return sig;
    }).toSet();
    
    print('🎨 Artist ${widget.artist.id} has ${widget.artist.setTimes.length} set times, ${signatures.length} marked as updated');
    
    setState(() {
      _updatedSetTimeSignatures = signatures;
      _isLoadingUpdatedSetTimes = false;
    });
  }
  
  bool _isSetTimeUpdated(SetTime setTime) {
    // Signature format must match _findUpdatedSetTimes: start_end_stage_status
    final signature = '${setTime.start}_${setTime.end}_${setTime.stage}_${setTime.status}';
    final isUpdated = _updatedSetTimeSignatures.contains(signature);
    if (isUpdated) {
      print('✅ Set time ${setTime.start} is marked as UPDATED');
    }
    return isUpdated;
  }

  void _initializeAnimations() {
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: RetroTheme.hotPink,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: RetroTheme.darkBlue,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _glitchController,
                builder: (context, child) {
                  return Text(
                    'ARTIST',
                    style: TextStyle(
                      color: RetroTheme.neonCyan,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  );
                },
              ),
            ),
            // Favorite heart icon in top right
            IconButton(
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited ? Colors.red : RetroTheme.neonCyan,
                size: 24,
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await FavoritesService.toggleFavorite(widget.artist.id);
                setState(() {
                  _isFavorited = !_isFavorited;
                });
              },
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: RetroTheme.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artist photo and name
              _buildArtistHeader(),
              
              const SizedBox(height: 24),
              
              // Status indicators (only show if cancelled)
              if (widget.artist.setTimes.any((st) => st.status == 'cancelled')) ...[
                _buildStatusSection(),
                const SizedBox(height: 24),
              ],
              
              // Set times
              _buildSetTimesSection(),
              
              const SizedBox(height: 24),
              
              // Links section
              if (widget.artist.hasLinks) ...[
                _buildLinksSection(),
                const SizedBox(height: 24),
              ],
              
              // Artist info (placeholder for future blurb)
              if (widget.artist.blurb != null) ...[
                _buildInfoSection(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistHeader() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: RetroTheme.hotPink.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Artist photo
              Container(
                width: double.infinity,
                height: 300,
                child: Image.asset(
                  widget.artist.photo,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: RetroTheme.darkBlue,
                      child: const Icon(
                        Icons.music_note,
                        color: RetroTheme.hotPink,
                        size: 80,
                      ),
                    );
                  },
                ),
              ),
              
              // Artist name (no background)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.artist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFamily: 'Verdana',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusSection() {
    // Only show cancelled status prominently
    final hasCancelled = widget.artist.setTimes.any((st) => st.status == 'cancelled');
    if (!hasCancelled) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: RetroTheme.errorRed, width: 3),
        borderRadius: BorderRadius.circular(4),
        color: RetroTheme.errorRed.withValues(alpha: 0.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel, color: RetroTheme.errorRed, size: 24),
          const SizedBox(width: 12),
          _buildStatusChip('CANCELLED', RetroTheme.errorRed),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }


  Widget _buildSetTimesSection() {
    if (widget.artist.setTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SET TIMES',
            style: TextStyle(
              color: RetroTheme.neonCyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.artist.setTimes.map((setTime) {
            Color statusColor = RetroTheme.electricGreen;
            if (setTime.isLive) {
              statusColor = RetroTheme.hotPink;
            } else if (setTime.isCompleted) {
              statusColor = RetroTheme.neonCyan.withValues(alpha: 0.6);
            }
            
            final isUpdated = _isSetTimeUpdated(setTime);
            final highlightColor = isUpdated ? RetroTheme.electricGreen : statusColor;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: highlightColor.withValues(alpha: isUpdated ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(4),
                // Removed border
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          setTime.stage,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Verdana',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDayAndTime(setTime.startDateTime)} - ${_formatTime(setTime.endDateTime)}',
                          style: TextStyle(
                            color: statusColor.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontFamily: 'Verdana',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUpdated) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: RetroTheme.electricGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'UPDATED',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (setTime.isLive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: RetroTheme.hotPink,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLinksSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RetroTheme.retroBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LINKS',
            style: TextStyle(
              color: RetroTheme.neonCyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.artist.website != null) ...[
            _buildLinkButton(
              'Website',
              Icons.language,
              RetroTheme.electricGreen,
              () => _launchUrl(widget.artist.website!),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.artist.bandcamp != null) ...[
            _buildLinkButton(
              'Bandcamp',
              Icons.music_note,
              RetroTheme.hotPink,
              () => _launchUrl(widget.artist.bandcamp!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Verdana',
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RetroTheme.retroBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ABOUT',
            style: TextStyle(
              color: RetroTheme.neonCyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.artist.blurb!,
            style: const TextStyle(
              color: RetroTheme.electricGreen,
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Verdana',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDayAndTime(DateTime dateTime) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[dateTime.weekday - 1];
    return '$dayName ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
