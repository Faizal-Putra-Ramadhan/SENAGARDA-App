import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rover_status.dart';
import '../theme/app_theme.dart';

/// Panel KIRI: mode switch, tombol rekam, tombol tandai titik.
/// Ditempel di tepi kiri layar (landscape) -- dijangkau jempol tangan
/// kiri saat HP dipegang dua tangan, gaya kontrol drone/rover pada
/// umumnya (DJI Go, XAG).
class ModeRecordPanel extends StatelessWidget {
  final RoverStatus status;
  final void Function(String command) onCommand;
  final VoidCallback onHapusSemua;
  final VoidCallback onKalibrasiArah;

  const ModeRecordPanel({
    super.key,
    required this.status,
    required this.onCommand,
    required this.onHapusSemua,
    required this.onKalibrasiArah,
  });

  @override
  Widget build(BuildContext context) {
    final tampilkanTandaiTitik =
        status.mode == RoverMode.manual && status.isRecording;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeButton('MANUAL', RoverMode.manual),
              const SizedBox(width: 6),
              _modeButton('AUTO', RoverMode.autonomous),
            ],
          ),
          const SizedBox(height: 10),
          _recordButton(),
          if (status.mode == RoverMode.manual) ...[
            const SizedBox(height: 8),
            _kalibrasiArahButton(),
          ],
          if (tampilkanTandaiTitik) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min, // WAJIB: hindari lebar tak
              // terbatas -- panel ini tidak punya lebar tetap dari induknya.
              children: [
                _tandaiTitikButton(),
                if (status.waypoints.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _undoButton(),
                ],
              ],
            ),
            if (status.waypoints.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onHapusSemua,
                child: const Text(
                  'Hapus semua titik',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _modeButton(String label, RoverMode mode) {
    final active = status.mode == mode;
    return GestureDetector(
      onTap: () => onCommand(mode == RoverMode.manual ? 'MODE:M' : 'MODE:A'),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryGreen : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _kalibrasiArahButton() {
    return GestureDetector(
      onTap: onKalibrasiArah,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, color: Colors.white70, size: 15),
            SizedBox(width: 6),
            Text(
              'Kalibrasi Arah',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordButton() {
    final recording = status.isRecording;
    return GestureDetector(
      onTap: () => onCommand(recording ? 'REC:0' : 'REC:1'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: recording ? Colors.redAccent : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              recording ? Icons.stop : Icons.fiber_manual_record,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              recording ? 'Stop' : 'Rekam',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tandaiTitikButton() {
    return GestureDetector(
      onTap: () => onCommand('MARK'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentGold,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Color(0xFF1C2620), size: 16),
            const SizedBox(width: 6),
            Text(
              'Tandai (${status.waypoints.length})',
              style: const TextStyle(
                color: Color(0xFF1C2620),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Batalkan waypoint TERAKHIR -- koreksi cepat kalau salah tandai titik.
  Widget _undoButton() {
    return GestureDetector(
      onTap: () => onCommand('UNMARK_LAST'),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.undo_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Panel KANAN: D-pad arah gerak. Cuma tampil saat mode Manual --
/// ditempel di tepi kanan layar, dijangkau jempol tangan kanan.
class DirectionalPad extends StatelessWidget {
  final void Function(String command) onCommand;

  const DirectionalPad({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dirButton(Icons.keyboard_arrow_up_rounded, 'F'),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dirButton(Icons.keyboard_arrow_left_rounded, 'L'),
              const SizedBox(width: 6),
              _stopButton(),
              const SizedBox(width: 6),
              _dirButton(Icons.keyboard_arrow_right_rounded, 'R'),
            ],
          ),
          const SizedBox(height: 6),
          _dirButton(Icons.keyboard_arrow_down_rounded, 'B'),
        ],
      ),
    );
  }

  Widget _dirButton(IconData icon, String command) {
    // Tombol arah: TEKAN-TAHAN, bukan tap sekali. Selagi ditekan,
    // perintah dikirim berulang tiap 150ms (menjaga rover tetap
    // bergerak & failsafe firmware tidak memicu). Saat dilepas,
    // langsung kirim 'S' sekali supaya berhenti seketika.
    return _TombolTekanTahan(
      icon: icon,
      warna: AppTheme.primaryGreen,
      onTekan: () => onCommand(command),
      onLepas: () => onCommand('S'),
    );
  }

  Widget _stopButton() {
    return GestureDetector(
      onTap: () => onCommand('S'),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.dangerRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

/// Tombol tekan-tahan: selagi jari masih di tombol, [onTekan] dipanggil
/// berulang tiap 150ms (bukan cuma sekali saat disentuh). Begitu jari
/// diangkat/dibatalkan, [onLepas] dipanggil SEKALI.
///
/// Dipakai utk tombol arah supaya rover jalan TERUS selama tombol
/// ditekan (gaya joystick/RC), bukan gerak sekali per ketukan.
class _TombolTekanTahan extends StatefulWidget {
  final IconData icon;
  final Color warna;
  final VoidCallback onTekan;
  final VoidCallback onLepas;

  const _TombolTekanTahan({
    required this.icon,
    required this.warna,
    required this.onTekan,
    required this.onLepas,
  });

  @override
  State<_TombolTekanTahan> createState() => _TombolTekanTahanState();
}

class _TombolTekanTahanState extends State<_TombolTekanTahan> {
  Timer? _timer;
  bool _ditekan = false;

  void _mulai() {
    widget.onTekan(); // langsung kirim sekali saat disentuh (responsif)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      widget.onTekan();
    });
    setState(() => _ditekan = true);
  }

  void _berhenti() {
    _timer?.cancel();
    _timer = null;
    if (_ditekan) widget.onLepas();
    setState(() => _ditekan = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _mulai(),
      onTapUp: (_) => _berhenti(),
      onTapCancel: _berhenti,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Sedikit gelap saat ditekan -- umpan balik visual jelas
          // bahwa tombol sedang aktif mengirim perintah berulang.
          color: _ditekan
              ? widget.warna.withOpacity(0.75)
              : widget.warna,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(widget.icon, color: Colors.white, size: 26),
      ),
    );
  }
}

/// Panel kanan saat mode Autonomous -- kalau sudah ada waypoint (dari
/// hasil "Tandai Titik" di mode Manual), tampilkan tombol JALANKAN yang
/// mengirim seluruh jalur ke rover sekaligus (perintah "PLAY").
/// Kalau belum ada waypoint, tampilkan pesan supaya operator tahu harus
/// rekam jalur dulu di mode Manual.
class AutoRunPanel extends StatelessWidget {
  final RoverStatus status;
  final void Function(String command) onCommand;
  final VoidCallback onHapusSemua;

  const AutoRunPanel({
    super.key,
    required this.status,
    required this.onCommand,
    required this.onHapusSemua,
  });

  @override
  Widget build(BuildContext context) {
    final adaJalur = status.waypoints.isNotEmpty;
    final isPlaying = status.isPlaying;

    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 170),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                color: AppTheme.accentGold,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Autonomous',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (adaJalur) ...[
            if (isPlaying) ...[
              // Sedang jalan -> tampilkan progres dan tombol Berhenti
              Text(
                'Menuju titik ${(status.currentWaypointIndex + 1).clamp(1, status.waypoints.length)} / ${status.waypoints.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => onCommand('STOP_AUTO'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Berhenti',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Belum jalan -> tampilkan tombol Jalankan
              GestureDetector(
                onTap: () => onCommand('PLAY'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF1C2620),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Jalankan (${status.waypoints.length})',
                        style: const TextStyle(
                          color: Color(0xFF1C2620),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onHapusSemua,
                child: const Text(
                  'Hapus semua titik',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ]
          ] else
            const Text(
              'Belum ada titik. Rekam jalur dulu di mode Manual.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
