import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/flutter_map_widget.dart';
import '../models/rover_status.dart';
import '../services/rover_service.dart';
import '../theme/app_theme.dart';
import '../widgets/control_panel.dart';
import '../widgets/status_bar.dart';
import 'connect_screen.dart';

/// Layar utama aplikasi: peta full-screen sebagai latar, dengan status 
/// bar mengambang di atas dan panel kontrol mengambang di kiri-kanan.
/// Peta ini menggunakan FlutterMapWidget lokal.
class ControlScreen extends StatefulWidget {
  final RoverService roverService;
  final VoidCallback onDisconnect;

  const ControlScreen({super.key, required this.roverService, required this.onDisconnect});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late final RoverService _roverService;
  bool _ikutiRover = true;
  StreamSubscription<RoverStatus>? _pemantauKoneksi;

  @override
  void initState() {
    super.initState();
    _roverService = widget.roverService;

    // Pantau koneksi -- kalau Bluetooth putus di tengah pemakaian
    // (mis. setelah misi autonomous selesai), arahkan balik ke layar
    // Connect otomatis, jangan biarkan operator terjebak di layar ini
    // dengan tombol yang diam-diam tidak berfungsi lagi.
    _pemantauKoneksi = _roverService.statusStream.listen((status) {
      if (!status.connected && mounted) {
        _tampilkanTerputus();
      }
    });
  }

  void _tampilkanTerputus() {
    _pemantauKoneksi?.cancel(); // cegah terpanggil berkali-kali
    widget.onDisconnect();
  }

  @override
  void dispose() {
    _pemantauKoneksi?.cancel();
    _roverService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<RoverStatus>(
        stream: _roverService.statusStream,
        initialData: _roverService.currentStatus,
        builder: (context, snapshot) {
          final status = snapshot.data ?? RoverStatus.initial();
          final adaFixGps = status.lat != 0 || status.lng != 0;

          return Stack(
            children: [
              _buildMap(status, adaFixGps),
              if (!adaFixGps)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentGold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Mencari sinyal GPS... (${status.satellites} satelit)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: StatusBar(status: status)),
                        Padding(
                          padding: const EdgeInsets.only(top: 12, right: 12),
                          child: _buildRecenterButton(),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final panelKiri = ModeRecordPanel(
                            status: status,
                            onCommand: _roverService.sendCommand,
                            onHapusSemua: _konfirmasiHapusSemua,
                            onKalibrasiArah: _konfirmasiKalibrasiArah,
                          );
                          final panelKanan = status.mode == RoverMode.manual
                              ? DirectionalPad(
                                  onCommand: _roverService.sendCommand,
                                )
                              : AutoRunPanel(
                                  status: status,
                                  onCommand: _roverService.sendCommand,
                                  onHapusSemua: _konfirmasiHapusSemua,
                                );

                          // Layar cukup lebar (landscape / tablet) →
                          // panel kiri-kanan sejajar seperti layout DJI.
                          if (constraints.maxWidth >= 500) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(child: panelKiri),
                                const SizedBox(width: 12),
                                panelKanan,
                              ],
                            );
                          }

                          // Layar sempit (portrait / HP biasa) →
                          // tumpuk vertikal supaya semua tombol tetap
                          // terlihat dan bisa diakses, tidak terpotong.
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: panelKanan,
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: panelKiri,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(RoverStatus status, bool adaFixGps) {
    return FlutterMapWidget(
      status: status,
      ikutiRover: _ikutiRover,
      onIkutiRoverChanged: (val) {
        setState(() => _ikutiRover = val);
      },
    );
  }

  Widget _buildRecenterButton() {
    return FloatingActionButton.small(
      heroTag: 'recenter',
      backgroundColor: AppTheme.primaryGreen,
      onPressed: () {
        setState(() => _ikutiRover = true);
      },
      child: const Icon(Icons.my_location_rounded, color: Colors.white),
    );
  }

  /// Dialog konfirmasi sebelum menghapus SEMUA waypoint -- sengaja butuh
  /// konfirmasi (beda dari "Batalkan Terakhir" yang langsung jalan)
  /// karena ini menghapus seluruh misi yang sedang direkam, tidak bisa
  /// dibatalkan.
  void _konfirmasiHapusSemua() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101410),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Hapus semua titik?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Semua titik yang sudah ditandai di misi ini akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _roverService.sendCommand('CLEAR_WAYPOINTS');
              Navigator.pop(context);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog konfirmasi sebelum kalibrasi arah -- WAJIB konfirmasi krn
  /// rover akan MAJU FISIK ~2 meter sendiri saat kalibrasi jalan (rover
  /// bandingkan arah gerak GPS vs heading IMU relatif, hasilnya jadi
  /// koreksi permanen sampai rover dimatikan). Operator harus pastikan
  /// ada ruang kosong di depan rover dulu.
  void _konfirmasiKalibrasiArah() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101410),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Kalibrasi arah?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Rover akan MAJU SENDIRI sekitar 2 meter untuk menyelaraskan '
          'arah dengan GPS. Pastikan ada ruang kosong di depan rover '
          'sebelum lanjut.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _roverService.sendCommand('KALIBRASI_ARAH');
              Navigator.pop(context);
            },
            child: const Text(
              'Mulai',
              style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu info berisi foto rover ASLI (tampak samping) + ringkasan
  /// status -- muncul saat marker rover di peta disentuh. Foto ini
  /// TIDAK dipakai sebagai ikon marker yang berputar karena tampak
  /// samping tidak masuk akal diputar mengikuti heading di peta
  /// (perlu tampak ATAS untuk itu, lihat catatan di _buildMap).
  void _tampilkanInfoRover(RoverStatus status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        // Batasi tinggi maksimal -- PENTING di landscape (tinggi layar
        // sangat terbatas), supaya tidak overflow seperti sebelumnya.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          // Jaring pengaman: kalau konten TETAP lebih tinggi dari batas
          // di atas (mis. HP layar sangat pendek), bisa di-scroll,
          // bukan overflow/error.
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101410),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.asset(
                      'assets/images/rover_foto.png',
                      height: 100, // diperkecil dari 150, biar muat di landscape
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SENAGARDA Rover',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Heading ${status.heading.toStringAsFixed(0)}°  •  '
                  '${status.satellites} satelit  •  '
                  '${status.mode == RoverMode.manual ? "Manual" : "Autonomous"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
