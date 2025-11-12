import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/remote_lineup_sync_service.dart';
import 'screens/conspiracy_splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/simple_player_screen.dart';
import 'screens/lineup_list_screen.dart';
import 'screens/ticket_input_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/feedback_screen.dart';
import 'services/lineup_service.dart';
import 'utils/platform_utils.dart' if (dart.library.html) 'utils/platform_utils_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  // Initialize notification service (skip on macOS/desktop)
  if (!kIsWeb && (PlatformUtils.isAndroid || PlatformUtils.isIOS)) {
    try {
      await NotificationService().initialize();
    } catch (e) {
      print('Warning: Failed to initialize notifications: $e');
    }
  }
  
  // Preload lineup data in background if cached data exists
  // This makes the lineup screen load instantly when opened
  // ignore: unawaited_futures
  RemoteLineupSyncService().hasCachedData().then((hasCached) async {
    if (hasCached) {
      await RemoteLineupSyncService().preloadIfCached();
    }
  });
  
  // Configure system UI overlay style (mobile only)
  if (!kIsWeb && (PlatformUtils.isAndroid || PlatformUtils.isIOS)) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    // Set preferred orientations (mobile only)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
  runApp(const FlutterViewerApp());
}

class FlutterViewerApp extends StatefulWidget {
  const FlutterViewerApp({super.key});

  @override
  State<FlutterViewerApp> createState() => _FlutterViewerAppState();
}

class _FlutterViewerAppState extends State<FlutterViewerApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for pending notifications after app is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check for pending notifications when app resumes
    if (state == AppLifecycleState.resumed) {
      _checkPendingNotifications();
    }
  }

  Future<void> _checkPendingNotifications() async {
    // Wait a bit for navigation to be ready
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    final pending = await NotificationService().getPendingNotification();
    if (pending != null && navigatorKey.currentContext != null) {
      _handleNotificationNavigation(pending);
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> payload) {
    final type = payload['type'] as String;
    final redirect = payload['redirect'] as String?;
    
    // Check if notification wants to redirect to updates page
    if (redirect == 'updates') {
      _navigateToUpdates();
      return;
    }
    
    if (type == 'single_artist') {
      final artistId = payload['artistId'] as int;
      _navigateToArtist(artistId);
    } else if (type == 'multiple_artists') {
      final artistIds = (payload['artistIds'] as List).cast<int>();
      _navigateToLineupWithMarkers(artistIds);
    }
  }

  void _navigateToUpdates() {
    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).pushNamed('/updates');
    }
  }

  Future<void> _navigateToArtist(int artistId) async {
    final lineupService = LineupService();
    final artist = await lineupService.getArtistById(artistId);
    
    if (artist != null && navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(artist: artist),
        ),
      );
    }
  }

  void _navigateToLineupWithMarkers(List<int> artistIds) {
    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => LineupListScreen(updatedArtistIds: artistIds),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Live Stream Viewer',
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.darkTheme,
        home: const ConspiracySplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/ticket': (context) => const TicketInputScreen(),
          '/menu': (context) => const MainMenuScreen(),
          '/player': (context) => const SimplePlayerScreen(),
          '/lineup': (context) => const LineupListScreen(),
          '/updates': (context) => const UpdatesScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/feedback': (context) => const FeedbackScreen(),
        },
      ),
    );
  }
}
