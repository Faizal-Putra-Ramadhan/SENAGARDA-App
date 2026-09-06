import 'package:flutter/material.dart';
import '../models/rover_status.dart';
import '../theme/app_theme.dart';

/// Panel status ringkas mengambang di atas peta, terinspirasi tata letak
/// status bar DJI Go / XAG -- info penting terlihat sekilas tanpa
/// menutupi peta.
class StatusBar extends StatelessWidget {
  final RoverStatus status;

  const StatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _connectionDot(),
              const SizedBox(width: 10),
              _infoChip(Icons.satellite_alt_outlined, '${status.satellites}'),
              const SizedBox(width: 14),
              _infoChip(
                Icons.explore_outlined,
                '${status.heading.toStringAsFixed(0)}°',
              ),
              const Spacer(),
              if (status.isRecording) ...[
                _recordingBadge(),
                const SizedBox(width: 8),
              ],
              _modeBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoChip(
                Icons.location_on_outlined, 
                'Lat: ${status.lat.toStringAsFixed(5)}, Lng: ${status.lng.toStringAsFixed(5)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _connectionDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.connected ? AppTheme.successGreen : AppTheme.dangerRed,
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _recordingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 11, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeBadge() {
    final isAuto = status.mode == RoverMode.autonomous;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isAuto ? AppTheme.accentGold : Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAuto ? 'AUTO' : 'MANUAL',
        style: TextStyle(
          color: isAuto ? const Color(0xFF1C2620) : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
