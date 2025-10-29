import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'screens/conspiracy_splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/simple_player_screen.dart';
import 'screens/lineup_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Set preferred orientations (optional)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const FlutterViewerApp());
}

class FlutterViewerApp extends StatelessWidget {
  const FlutterViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Live Stream Viewer',
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.darkTheme,
        home: const ConspiracySplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/menu': (context) => const MainMenuScreen(),
          '/player': (context) => const SimplePlayerScreen(),
          '/lineup': (context) => const LineupListScreen(),
        },
      ),
    );
  }
}
