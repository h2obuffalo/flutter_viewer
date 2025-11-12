import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/artist.dart';
import '../services/lineup_service.dart';
import '../services/remote_lineup_sync_service.dart';
import '../services/favorites_service.dart';
import '../services/now_playing_service.dart';
import 'artist_detail_screen.dart';

// Stage color mapping
Color getStageColor(String stage) {
  switch (stage) {
    case 'Main Stage':
      return RetroTheme.neonCyan.withValues(alpha: 0.2);
    case 'BANG FACE TV Live':
      return RetroTheme.hotPink.withValues(alpha: 0.2);
    case 'Hard Crew Heroes':
      return RetroTheme.warningYellow.withValues(alpha: 0.2);
    case 'MAD':
      return const Color(0xFF9D00FF).withValues(alpha: 0.2); // Purple
    case 'Jungyals\'n\'Gays':
      return RetroTheme.electricGreen.withValues(alpha: 0.2);
    default:
      return RetroTheme.darkGray;
  }
}

class LineupListScreen extends StatefulWidget {
  final bool showNowPlaying;
  final List<int>?
      updatedArtistIds; // IDs of artists that were recently updated

  const LineupListScreen({
    super.key,
    this.showNowPlaying = false,
    this.updatedArtistIds,
  });

  @override
  State<LineupListScreen> createState() => _LineupListScreenState();
}

class _LineupListScreenState extends State<LineupListScreen>
    with TickerProviderStateMixin {
  final LineupService _lineupService = LineupService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Artist> _artists = [];
  List<Artist> _filteredArtists = [];
  List<String> _stages = [];
  String? _selectedStage;
  List<String> _days = ['Friday', 'Saturday', 'Sunday'];
  String? _selectedDay;
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  bool _showFavoritesOnly = false;
  int _sortMode = 0; // 0 = alphabetical, 1 = stage order, 2 = time order
  Set<int> _updatedArtistIds =
      {}; // Track which artists were updated (set time/stage changes)
  Set<int> _newArtistIds = {}; // Track which artists are newly added

  late AnimationController _glitchController;
  late AnimationController _pulseController;
  late AnimationController _refreshController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _selectedStage = null; // 'All Stages'
    _selectedDay = 'Friday'; // Default to Friday

    // Track updated artists from notification
    if (widget.updatedArtistIds != null) {
      _updatedArtistIds = widget.updatedArtistIds!.toSet();
    }

    _initializeAnimations();
    _loadData();
    _loadUpdatedArtists();
    // Don't check for changes on screen open - only notify from background checks or manual refresh

    // Listen for lineup changes from RemoteLineupSyncService
    RemoteLineupSyncService().addListener(_onLineupChanged);

    // Listen for focus changes to collapse search when keyboard closes
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.isEmpty) {
        setState(() {
          _isSearchExpanded = false;
        });
      }
    });
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

    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  Future<void> _loadUpdatedArtists() async {
    // Load updated artist IDs from RemoteLineupSyncService
    final prefs = await SharedPreferences.getInstance();
    const String updatedArtistsKey = 'lineup.updated.artists';
    final updatedIdsStr = prefs.getStringList(updatedArtistsKey) ?? [];
    final updatedIds = updatedIdsStr.map((s) => int.parse(s)).toSet();

    // Separate new artists from updated artists
    const String knownIdsKey = 'lineup.known.artist.ids';
    final knownIdsStr = prefs.getStringList(knownIdsKey) ?? [];
    final knownIds = knownIdsStr.map((s) => int.parse(s)).toSet();

    final hasUpdatedArtists = updatedIds.isNotEmpty;

    if (mounted) {
      setState(() {
        _updatedArtistIds =
            updatedIds.where((id) => knownIds.contains(id)).toSet();
        _newArtistIds =
            updatedIds.where((id) => !knownIds.contains(id)).toSet();
      });
    }

    print(
        '🎨 Loaded updated artists: ${_updatedArtistIds.length} updated, ${_newArtistIds.length} new');

    // If there are updated artists, force refresh the lineup data to show latest info
    if (hasUpdatedArtists) {
      print('🔄 Detected updated artists, refreshing lineup data...');
      await _lineupService.refreshData();
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      List<Artist> artists;
      if (widget.showNowPlaying) {
        // Load now playing data
        await NowPlayingService.loadArtists();
        artists = NowPlayingService.getNowPlayingAndUpcoming();
      } else {
        // Load all artists
        artists = await _lineupService.getAllArtists();
      }

      final stages = await _lineupService.getAllStages();
      final favoriteIds = await FavoritesService.getFavoriteIds();

      setState(() {
        _artists = artists.map((artist) {
          artist.isFavorited = favoriteIds.contains(artist.id);
          return artist;
        }).toList();
        _filteredArtists = _artists;
        _stages = stages;
        _isLoading = false;
      });
      _filterArtists();
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

        final matchesStage =
            _selectedStage == null || artist.stages.contains(_selectedStage);

        final matchesDay = _selectedDay == null ||
            _artistMatchesDay(artist, _selectedDay!);

        final matchesFavorites = !_showFavoritesOnly || artist.isFavorited;

        return matchesSearch && matchesStage && matchesDay && matchesFavorites;
      }).toList();

      // Sort based on user preference
      switch (_sortMode) {
        case 0: // Alphabetical
          _filteredArtists.sort((a, b) {
            // Normalize names: remove special characters but keep numbers
            String normalize(String name) {
              // Remove all special characters except alphanumeric and spaces
              return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
            }

            // Check if names start with numbers
            String aNormalized = normalize(a.name);
            String bNormalized = normalize(b.name);

            // Extract first character for comparison
            bool aStartsWithNumber = aNormalized.isNotEmpty &&
                aNormalized[0].codeUnitAt(0) >= 48 &&
                aNormalized[0].codeUnitAt(0) <= 57; // 0-9

            bool bStartsWithNumber = bNormalized.isNotEmpty &&
                bNormalized[0].codeUnitAt(0) >= 48 &&
                bNormalized[0].codeUnitAt(0) <= 57; // 0-9

            // Numbers come first
            if (aStartsWithNumber && !bStartsWithNumber) return -1;
            if (!aStartsWithNumber && bStartsWithNumber) return 1;

            // Both same type (both numbers or both letters), compare alphabetically
            return aNormalized.compareTo(bNormalized);
          });
          break;
        case 1: // Stage order
          _filteredArtists.sort((a, b) {
            // First sort by stage priority
            final stageOrder = [
              'Main Stage',
              'BANG FACE TV Live',
              'Hard Crew Heroes',
              'MAD',
              'Jungyals\'n\'Gays'
            ];
            final aStageIndex = stageOrder.indexOf(a.primaryStage);
            final bStageIndex = stageOrder.indexOf(b.primaryStage);

            if (aStageIndex != bStageIndex) {
              return aStageIndex.compareTo(bStageIndex);
            }

            // If same stage, maintain original order (by ID)
            return a.id.compareTo(b.id);
          });
          break;
        case 2: // Time order
          _filteredArtists.sort((a, b) {
            // Sort by earliest set time
            final aEarliestTime = a.setTimes.isNotEmpty
                ? DateTime.parse(a.setTimes.first.start)
                : DateTime(2099); // Put artists without times at end
            final bEarliestTime = b.setTimes.isNotEmpty
                ? DateTime.parse(b.setTimes.first.start)
                : DateTime(2099);

            return aEarliestTime.compareTo(bEarliestTime);
          });
          break;
      }
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

  void _onDayChanged(String? day) {
    setState(() {
      _selectedDay = day;
    });
    _filterArtists();
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
    });
    _filterArtists();
  }

  void _toggleFavorite(Artist artist) async {
    await FavoritesService.toggleFavorite(artist.id);
    setState(() {
      artist.isFavorited = !artist.isFavorited;
    });
    _filterArtists();
  }

  void _toggleSorting() {
    setState(() {
      _sortMode = (_sortMode + 1) % 3; // Cycle through 0, 1, 2
    });
    _filterArtists();
  }

  bool _artistMatchesDay(Artist artist, String day) {
    if (artist.setTimes.isEmpty) return false;

    // Get all unique dates from ALL artists to find the festival start date
    // Use the earliest date as the festival start (Friday)
    final Set<String> uniqueDates = {};
    for (final a in _artists) {
      for (final setTime in a.setTimes) {
        final setDate = setTime.start.split('T')[0];
        uniqueDates.add(setDate);
      }
    }

    if (uniqueDates.isEmpty) return false;
    final sortedDates = uniqueDates.toList()..sort();
    final mainFestivalStart = sortedDates.first; // Earliest date = Friday

    final firstDateTime = DateTime.parse(mainFestivalStart);

    // Map day names to their index (Friday=0, Saturday=1, Sunday=2)
    final dayIndexMap = {'Friday': 0, 'Saturday': 1, 'Sunday': 2};

    final targetDayIndex = dayIndexMap[day];
    if (targetDayIndex == null) return false;

    // Calculate the expected date based on main festival start date being Friday
    final targetDate = firstDateTime.add(Duration(days: targetDayIndex));
    final targetDateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    // Handle overnight sets: times after 00:00 but before 06:00 count as previous day
    return artist.setTimes.any((setTime) {
      final setDateStr = setTime.start.split('T')[0];
      final setDate = DateTime.parse(setTime.start);

      // If set starts before 6am, it counts as the previous day's late set
      if (setDate.hour < 6) {
        final previousDay = setDate.subtract(const Duration(days: 1));
        final previousDayStr =
            '${previousDay.year}-${previousDay.month.toString().padLeft(2, '0')}-${previousDay.day.toString().padLeft(2, '0')}';
        return previousDayStr == targetDateStr;
      }

      return setDateStr == targetDateStr;
    });
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
    RemoteLineupSyncService().removeListener(_onLineupChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _glitchController.dispose();
    _pulseController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _onLineupChanged() {
    // When RemoteLineupSyncService notifies of changes, reload updated artists
    if (mounted) {
      _loadUpdatedArtists();
    }
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
              widget.showNowPlaying ? 'WHAT\'S THE CRACK' : 'LINEUP',
              style: TextStyle(
                color: RetroTheme.neonCyan,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh lineup',
            icon: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_refreshController),
              child: const Icon(Icons.refresh, color: RetroTheme.neonCyan),
            ),
            onPressed: _isRefreshing
                ? null
                : () async {
                    print('🔘 Refresh button pressed');
                    setState(() {
                      _isRefreshing = true;
                    });
                    _refreshController.repeat();

                    try {
                      // Manual refresh should send notifications
                      // Clear LineupService cache to ensure fresh data
                      _lineupService.clearCache();
                      print('🔘 Cache cleared, calling refreshIfChanged...');
                      final changed = await RemoteLineupSyncService()
                          .refreshIfChanged(sendNotifications: true);
                      print('🔘 refreshIfChanged returned: $changed');
                      if (!mounted) return;
                      // Always reload data after refresh, even if no changes detected
                      // (in case cache was stale)
                      await _loadData();
                      // Reload updated artists to show dots/badges
                      await _loadUpdatedArtists();
                      if (!mounted) return;
                      if (changed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lineup updated')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No updates available')),
                        );
                      }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: RetroTheme.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Stage filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                margin: const EdgeInsets.only(
                    top: 16, bottom: 8, left: 8, right: 8),
                decoration: RetroTheme.retroBorder,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStage,
                    hint: const Text(
                      'All Stages',
                      style: TextStyle(color: RetroTheme.electricGreen),
                    ),
                    isExpanded: true,
                    dropdownColor: RetroTheme.darkGray,
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
                              style: const TextStyle(
                                  color: RetroTheme.electricGreen),
                            ),
                          )),
                    ],
                    onChanged: _onStageChanged,
                  ),
                ),
              ),

              // Day filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                decoration: RetroTheme.retroBorder,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDay,
                    isExpanded: true,
                    dropdownColor: RetroTheme.darkGray,
                    items: _days.map((day) => DropdownMenuItem<String>(
                          value: day,
                          child: Text(
                            day,
                            style: const TextStyle(
                                color: RetroTheme.electricGreen),
                          ),
                        )).toList(),
                    onChanged: _onDayChanged,
                  ),
                ),
              ),

              // Results count and sort button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
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
                            Flexible(
                              child: Text(
                                _selectedStage!,
                                style: const TextStyle(
                                  color: RetroTheme.electricGreen,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Favorites toggle button - HEART ICON ONLY
                    GestureDetector(
                      onTap: _toggleFavoritesFilter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6), // Match sort button height
                        decoration: RetroTheme.retroBorder,
                        child: Icon(
                          _showFavoritesOnly
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sort button - fixed width to prevent shifting
                    GestureDetector(
                      onTap: _toggleSorting,
                      child: Container(
                        width:
                            85, // Fixed width to accommodate "Stage" text (longest option)
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: RetroTheme.retroBorder,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sortMode == 0
                                  ? Icons.sort_by_alpha
                                  : _sortMode == 1
                                      ? Icons.event
                                      : Icons.schedule,
                              color: RetroTheme.electricGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortMode == 0
                                  ? 'A-Z'
                                  : _sortMode == 1
                                      ? 'Stage'
                                      : 'Time',
                              style: const TextStyle(
                                color: RetroTheme.electricGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

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
                                  color:
                                      RetroTheme.hotPink.withValues(alpha: 0.5),
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
                                    color: RetroTheme.electricGreen
                                        .withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, bottom: 24),
                            itemCount: _filteredArtists.length,
                            itemBuilder: (context, index) {
                              final artist = _filteredArtists[index];
                              return _buildArtistCard(artist);
                            },
                          ),
              ),
            ],
          ),

          // Floating search button (bottom left)
          Positioned(
            left: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                });
                if (_isSearchExpanded) {
                  _searchFocusNode.requestFocus();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RetroTheme.darkBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSearchExpanded ? Icons.close : Icons.search,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Search overlay (appears above keyboard)
          if (_isSearchExpanded)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RetroTheme.darkBlue,
                  border: Border(
                    top: BorderSide(color: RetroTheme.neonCyan, width: 2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: RetroTheme.electricGreen),
                  decoration: InputDecoration(
                    hintText: 'Search artists...',
                    hintStyle: TextStyle(
                        color: RetroTheme.electricGreen.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: RetroTheme.neonCyan, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: RetroTheme.neonCyan, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: RetroTheme.electricGreen, width: 3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    filled: true,
                    fillColor: RetroTheme.darkGray,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtistCard(Artist artist) {
    // Get primary stage color for background
    final primaryStage = artist.primaryStage;
    final stageColor = getStageColor(primaryStage);
    final isUpdated = _updatedArtistIds.contains(artist.id);
    final isNew = _newArtistIds.contains(artist.id);
    final timeBadges = _buildSetTimeBadges(artist);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: stageColor,
        border: Border(
          bottom: BorderSide(
            color: RetroTheme.neonCyan.withValues(alpha: 0.3),
            width: 1,
          ),
          // Highlight border: green for new artists, none for updated (updated gets dot instead)
          left: isNew
              ? BorderSide(
                  color: RetroTheme.electricGreen,
                  width: 4,
                )
              : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: () => _onArtistTap(artist),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // 8-bit heart icon with larger tap area
              GestureDetector(
                onTap: () => _toggleFavorite(artist),
                behavior: HitTestBehavior.opaque, // Makes entire area tappable
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12), // Increased padding for larger tap area
                  child: Icon(
                    artist.isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: artist.isFavorited ? Colors.red : Colors.white,
                    size: 24, // Slightly larger icon
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // New artist badge (green border + NEW badge)
                        if (isNew) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: RetroTheme.electricGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Updated artist indicator (small green dot)
                        if (isUpdated && !isNew) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: RetroTheme.electricGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            artist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Verdana',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (timeBadges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: timeBadges,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: RetroTheme.neonCyan.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSetTimeBadges(Artist artist) {
    if (artist.setTimes.isEmpty) return const <Widget>[];

    final sortedTimes = List<SetTime>.from(artist.setTimes)
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    const maxVisible = 2;
    final badges = <Widget>[];

    for (final setTime in sortedTimes.take(maxVisible)) {
      badges.add(_buildSetTimeBadge(setTime));
    }

    final remaining = sortedTimes.length - maxVisible;
    if (remaining > 0) {
      badges.add(_buildAdditionalSetBadge(remaining));
    }

    return badges;
  }

  Widget _buildSetTimeBadge(SetTime setTime) {
    final label = _formatSetTime(setTime);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          letterSpacing: 0.3,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildAdditionalSetBadge(int remaining) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        '+$remaining more',
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _formatSetTime(SetTime setTime) {
    final start = setTime.startDateTime;
    final end = setTime.endDateTime;
    final dayLabel = DateFormat('EEE').format(start).toUpperCase();
    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(start);
    final endStr = timeFormat.format(end);
    final stageLabel = _abbreviateStageName(setTime.stage);
    return '$dayLabel $startStr–$endStr • $stageLabel';
  }

  String _abbreviateStageName(String stage) {
    switch (stage) {
      case 'BANG FACE TV Live':
        return 'BFTV';
      case 'Hard Crew Heroes':
        return 'HCH';
      case 'Jungyals\'n\'Gays':
        return 'J&G';
      default:
        return stage;
    }
  }
}
