import 'package:flutter/material.dart';
import '../services/rover_service.dart';
import '../services/websocket_rover_service.dart';
import '../theme/app_theme.dart';

/// Layar pertama yang dibuka -- pilih mode koneksi sebelum masuk ke
/// layar kontrol utama (peta+D-pad). Ada 2 opsi:
///   1. Sambungkan ke rover ASLI -- via WiFi (WebSocketRoverService)
///   2. Mode Simulasi -- data virtual (MockRoverService), uji UI/alur
///      tanpa hardware.
class ConnectScreen extends StatefulWidget {
  final void Function(RoverService) onConnected;

  const ConnectScreen({super.key, required this.onConnected});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _isConnecting = false;
  String? _errorMessage;

  Future<void> _connectWifi() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final service = WebSocketRoverService();
    try {
      await service.connect();
      if (mounted) {
        widget.onConnected(service);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Gagal menyambung ke WiFi Rover. Pastikan HP terhubung ke jaringan Rover.\n\nDetail: $e';
        });
      }
    }
  }

  void _mulaiModeSimulasi() {
    widget.onConnected(MockRoverService());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.agriculture_rounded,
                  size: 56,
                  color: AppTheme.accentGold,
                ),
                const SizedBox(height: 12),
                const Text(
                  'SENAGARDA Rover',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'NAWASENA - PPK Ormawa RDC UAD',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.dangerRed.withOpacity(0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (_isConnecting)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.accentGold),
                      SizedBox(height: 16),
                      Text(
                        'Menyambungkan ke WiFi Rover...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      SizedBox(height: 24),
                    ],
                  )
                else
                  SizedBox(
                    width: 280,
                    child: ElevatedButton.icon(
                      onPressed: _connectWifi,
                      icon: const Icon(Icons.wifi_rounded),
                      label: const Text('Sambungkan via WiFi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 280,
                  child: OutlinedButton.icon(
                    onPressed: _isConnecting ? null : _mulaiModeSimulasi,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Mode Simulasi (tanpa hardware)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
