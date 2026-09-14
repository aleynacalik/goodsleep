import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'sleep_log.dart';
import 'coach_screen.dart';
import 'routine_screen.dart';
import 'profile.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SleepLogScreen(),
    const CoachScreen(),
    const RoutineScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = Theme.of(context).colorScheme;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!isDark)
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: themeColors.surface,
          selectedItemColor: themeColors.primary,
          unselectedItemColor: isDark ? const Color(0xFF6C5A7D) : const Color(0xFFBDB3C7),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.home_filled, size: 24)),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.receipt_long_rounded, size: 24)),
              label: 'Günlük',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.school_rounded, size: 24)),
              label: 'Koç',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.playlist_play_rounded, size: 24)),
              label: 'Rutin',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 6, top: 8), child: Icon(Icons.person_rounded, size: 24)),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
