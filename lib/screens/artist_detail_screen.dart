import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/artist.dart';

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
  late AnimationController _glitchController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
        title: AnimatedBuilder(
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
              
              // Status indicators
              _buildStatusSection(),
              
              const SizedBox(height: 24),
              
              // Stage information
              _buildStageSection(),
              
              const SizedBox(height: 24),
              
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
              
              // Artist name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RetroTheme.darkBlue.withValues(alpha: 0.9),
                ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RetroTheme.retroBorder,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.artist.isCurrentlyPlaying) ...[
            _buildStatusChip('LIVE NOW', RetroTheme.hotPink),
          ] else if (widget.artist.hasUpcomingSets) ...[
            _buildStatusChip('UPCOMING', RetroTheme.electricGreen),
          ] else ...[
            _buildStatusChip('SCHEDULED', RetroTheme.neonCyan),
          ],
          
          if (widget.artist.hasLinks) ...[
            _buildStatusChip('HAS LINKS', RetroTheme.hotPink),
          ],
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

  Widget _buildStageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RetroTheme.retroBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STAGES',
            style: TextStyle(
              color: RetroTheme.neonCyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.artist.stages.map((stage) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: RetroTheme.electricGreen.withValues(alpha: 0.2),
                  border: Border.all(color: RetroTheme.electricGreen, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stage,
                  style: const TextStyle(
                    color: RetroTheme.electricGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSetTimesSection() {
    if (widget.artist.setTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RetroTheme.retroBorder,
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

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                border: Border.all(color: statusColor, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    setTime.isLive ? Icons.play_circle : 
                    setTime.isUpcoming ? Icons.schedule : Icons.check_circle,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(setTime.startDateTime)} - ${_formatTime(setTime.endDateTime)}',
                          style: TextStyle(
                            color: statusColor.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
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
}
