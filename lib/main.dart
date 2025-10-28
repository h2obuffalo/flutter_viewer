import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/simple_player_screen.dart';

void main() {
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
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/menu': (context) => const MainMenuScreen(),
          '/player': (context) => const SimplePlayerScreen(),
        },
      ),
    );
  }
}
