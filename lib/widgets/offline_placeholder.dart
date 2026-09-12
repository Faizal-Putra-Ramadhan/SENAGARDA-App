import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget yang ditampilkan ketika tidak ada koneksi internet.
/// Menampilkan emoji sedih dan pesan offline.
class OfflinePlaceholder extends StatelessWidget {
  const OfflinePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'NAWASENA',
          style: TextStyle(
            color: AppTheme.accentGold,
            letterSpacing: 1.2,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                ':(',
                style: TextStyle(
                  fontSize: 72,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Maaf, anda saat ini sedang\ndalam mode offline',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hubungkan ke internet untuk melihat data.\nAnda tetap bisa menggunakan Kontrol Rover melalui WiFi lokal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.wifi_off, color: Colors.white30, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
