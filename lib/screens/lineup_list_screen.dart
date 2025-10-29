import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/artist.dart';
import '../services/lineup_service.dart';
import 'artist_detail_screen.dart';

class LineupListScreen extends StatefulWidget {
  const LineupListScreen({super.key});

  @override
  State<LineupListScreen> createState() => _LineupListScreenState();
}

class _LineupListScreenState extends State<LineupListScreen> with TickerProviderStateMixin {
  final LineupService _lineupService = LineupService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Artist> _artists = [];
  List<Artist> _filteredArtists = [];
  List<String> _stages = [];
  String? _selectedStage;
  bool _isLoading = true;
  String _searchQuery = '';

  late AnimationController _glitchController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
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
  }

  Future<void> _loadData() async {
    try {
      final artists = await _lineupService.getAllArtists();
      final stages = await _lineupService.getAllStages();
      
      setState(() {
        _artists = artists;
        _filteredArtists = artists;
        _stages = stages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading lineup: $e'),
            backgroundColor: RetroTheme.hotPink,
          ),
        );
      }
    }
  }

  void _filterArtists() {
    setState(() {
      _filteredArtists = _artists.where((artist) {
        final matchesSearch = _searchQuery.isEmpty || 
            artist.name.toLowerCase().contains(_searchQuery.toLowerCase());
        
        final matchesStage = _selectedStage == null || 
            artist.stages.contains(_selectedStage);
        
        return matchesSearch && matchesStage;
      }).toList();
      
      // Sort by name
      _filteredArtists.sort((a, b) => a.name.compareTo(b.name));
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterArtists();
  }

  void _onStageChanged(String? stage) {
    setState(() {
      _selectedStage = stage;
    });
    _filterArtists();
  }

  void _onArtistTap(Artist artist) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailScreen(artist: artist),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _glitchController.dispose();
    _pulseController.dispose();
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
              'LINEUP',
              style: TextStyle(
                color: RetroTheme.neonCyan,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            );
          },
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: RetroTheme.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: RetroTheme.retroBorder,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: RetroTheme.electricGreen),
                    decoration: const InputDecoration(
                      hintText: 'Search artists...',
                      hintStyle: TextStyle(color: RetroTheme.electricGreen),
                      prefixIcon: Icon(Icons.search, color: RetroTheme.electricGreen),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Stage filter dropdown
                Container(
                  decoration: RetroTheme.retroBorder,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStage,
                      hint: const Text(
                        'All Stages',
                        style: TextStyle(color: RetroTheme.electricGreen),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'All Stages',
                            style: TextStyle(color: RetroTheme.electricGreen),
                          ),
                        ),
                        ..._stages.map((stage) => DropdownMenuItem<String>(
                          value: stage,
                          child: Text(
                            stage,
                            style: const TextStyle(color: RetroTheme.electricGreen),
                          ),
                        )),
                      ],
                      onChanged: _onStageChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredArtists.length} artists',
                  style: const TextStyle(
                    color: RetroTheme.hotPink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedStage != null) ...[
                  const Text(
                    ' • ',
                    style: TextStyle(color: RetroTheme.electricGreen),
                  ),
                  Text(
                    _selectedStage!,
                    style: const TextStyle(
                      color: RetroTheme.electricGreen,
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Artists list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: RetroTheme.neonCyan,
                    ),
                  )
                : _filteredArtists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 64,
                              color: RetroTheme.hotPink.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No artists found',
                              style: TextStyle(
                                color: RetroTheme.hotPink,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filter',
                              style: TextStyle(
                                color: RetroTheme.electricGreen.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredArtists.length,
                        itemBuilder: (context, index) {
                          final artist = _filteredArtists[index];
                          return _buildArtistCard(artist);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistCard(Artist artist) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: RetroTheme.neonCyan.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: RetroTheme.neonCyan.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ListTile(
            onTap: () => _onArtistTap(artist),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: RetroTheme.hotPink,
                  width: 2,
                ),
              ),
              child: Image.asset(
                artist.photo,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: RetroTheme.darkBlue,
                    child: const Icon(
                      Icons.music_note,
                      color: RetroTheme.hotPink,
                      size: 30,
                    ),
                  );
                },
              ),
            ),
            title: Text(
              artist.name,
              style: const TextStyle(
                color: RetroTheme.electricGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  artist.primaryStage,
                  style: TextStyle(
                    color: RetroTheme.neonCyan.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                if (artist.isCurrentlyPlaying) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ] else if (artist.hasUpcomingSets) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: RetroTheme.electricGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'UPCOMING',
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
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: RetroTheme.neonCyan.withOpacity(0.6),
              size: 16,
            ),
          ),
        );
      },
    );
  }
}
