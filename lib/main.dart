import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initAuth();
  await NotificationService.init();
  await NotificationService.requestPermissions();
  runApp(const GoodSleepApp());
}

class GoodSleepApp extends StatefulWidget {
  const GoodSleepApp({super.key});

  @override
  State<GoodSleepApp> createState() => _GoodSleepAppState();
}

class _GoodSleepAppState extends State<GoodSleepApp> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
  }

  Future<void> _loadStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'Little Dreams',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F0F6),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFB19CD9),
              secondary: Color(0xFFD8CADD),
              surface: Colors.white,
              onSurface: Color(0xFF2C223A),
            ),
            useMaterial3: true,
            fontFamily: GoogleFonts.nunito().fontFamily,
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F0F1A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFB19CD9),
              secondary: Color(0xFF382F44),
              surface: Color(0xFF1C1C2D),
              onSurface: Color(0xFFEBE3EE),
            ),
            useMaterial3: true,
            fontFamily: GoogleFonts.nunito().fontFamily,
          ),
          themeMode: currentMode,

          home: _onboardingDone == null
              ? const Scaffold(body: SizedBox.shrink())
              : !_onboardingDone!
                  ? const OnboardingScreen()
                  : ApiService.isLoggedIn
                      ? const MainNavigationScreen()
                      : const AuthScreen(),
        );
      },
    );
  }
}
