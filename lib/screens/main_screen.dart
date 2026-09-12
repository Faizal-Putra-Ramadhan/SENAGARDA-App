import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_placeholder.dart';
import 'dashboard_screen.dart';
import 'trap_screen.dart';
import 'rover_screen.dart';
import 'control_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Cek konektivitas setiap 10 detik
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      // Coba query ringan ke Supabase sebagai pengecekan koneksi.
      // Ini berfungsi di semua platform (web, mobile, desktop).
      await Supabase.instance.client
          .from('devices')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _isOnline = true);
    } catch (_) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  Widget _buildScreenForIndex(int index) {
    // Tab Control (index 3) selalu bisa diakses, bahkan offline
    if (index == 3) {
      return const ControlTab();
    }
    // Tab lain butuh online
    if (!_isOnline) {
      return const OfflinePlaceholder();
    }
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const TrapScreen();
      case 2:
        return const RoverScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreenForIndex(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E2320),
        selectedItemColor: AppTheme.accentGold,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pest_control_outlined),
            activeIcon: Icon(Icons.pest_control),
            label: 'Trap',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'Rover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_remote_outlined),
            activeIcon: Icon(Icons.settings_remote),
            label: 'Control',
          ),
        ],
      ),
    );
  }
}

