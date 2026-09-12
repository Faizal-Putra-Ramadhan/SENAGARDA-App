import 'dart:math';
import 'package:flutter/material.dart';
import '../models/rover_status.dart';
import '../theme/app_theme.dart';

class OfflineMap extends StatefulWidget {
  final RoverStatus status;
  final bool ikutiRover;
  final Function(bool) onIkutiRoverChanged;

  const OfflineMap({
    super.key,
    required this.status,
    required this.ikutiRover,
    required this.onIkutiRoverChanged,
  });

  @override
  State<OfflineMap> createState() => _OfflineMapState();
}

class _OfflineMapState extends State<OfflineMap> {
  // Center offset untuk pan map
  Offset _panOffset = Offset.zero;
  double _zoom = 1.0;

  @override
  void didUpdateWidget(covariant OfflineMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ikutiRover && !oldWidget.ikutiRover) {
      // Reset pan jika kembali mengikuti rover
      _panOffset = Offset.zero;
      _zoom = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (widget.ikutiRover) {
          widget.onIkutiRoverChanged(false);
        }
        setState(() {
          _panOffset += details.delta;
        });
      },
      child: Container(
        color: const Color(0xFF1E2320), // Warna background peta offline
        child: CustomPaint(
          size: Size.infinite,
          painter: _GridMapPainter(
            status: widget.status,
            panOffset: widget.ikutiRover ? Offset.zero : _panOffset,
            zoom: _zoom,
            ikutiRover: widget.ikutiRover,
          ),
        ),
      ),
    );
  }
}

class _GridMapPainter extends CustomPainter {
  final RoverStatus status;
  final Offset panOffset;
  final double zoom;
  final bool ikutiRover;

  _GridMapPainter({
    required this.status,
    required this.panOffset,
    required this.zoom,
    required this.ikutiRover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;
    
    // Draw Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const double gridSize = 50.0;
    final int hLines = (size.height / gridSize).ceil() * 2;
    final int vLines = (size.width / gridSize).ceil() * 2;

    for (int i = -hLines; i <= hLines; i++) {
      double y = center.dy + i * gridSize * zoom;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = -vLines; i <= vLines; i++) {
      double x = center.dx + i * gridSize * zoom;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Origin GPS reference (titik awal rover saat pertama dinyalakan/diterima)
    // Untuk peta lokal, kita asumsikan point pertama rover adalah (0,0) atau center
    // Jika tidak ada data GPS, tampilkan teks
    if (status.lat == 0 && status.lng == 0) return;

    // Skala meter ke piksel
    const metersToPixels = 10.0; // 1 meter = 10 piksel (disesuaikan)
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * cos(status.lat * pi / 180);

    // Fungsi konversi lat/lng ke koordinat lokal (relatif terhadap posisi rover saat ini jika ikutiRover)
    Offset latLngToLocal(double lat, double lng, double refLat, double refLng) {
      final dLat = (lat - refLat) * metersPerDegreeLat;
      final dLng = (lng - refLng) * metersPerDegreeLng;
      // Di layar koordinat: y positif itu ke bawah, x positif ke kanan
      // Secara geografis: lat positif ke utara (atas), lng positif ke timur (kanan)
      return Offset(dLng * metersToPixels * zoom, -dLat * metersToPixels * zoom);
    }

    // Referensi tengah (jika mengikuti rover, rover selalu di tengah)
    final refLat = ikutiRover ? status.lat : (status.waypoints.isNotEmpty ? status.waypoints.first.lat : status.lat);
    final refLng = ikutiRover ? status.lng : (status.waypoints.isNotEmpty ? status.waypoints.first.lng : status.lng);

    final refPoint = latLngToLocal(status.lat, status.lng, refLat, refLng);
    final roverPos = center + refPoint;

    // Gambar jalur/garis waypoint
    if (status.waypoints.isNotEmpty) {
      final pathPaint = Paint()
        ..color = AppTheme.accentGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * zoom;

      final path = Path();
      for (int i = 0; i < status.waypoints.length; i++) {
        final w = status.waypoints[i];
        final wpPos = center + latLngToLocal(w.lat, w.lng, refLat, refLng);
        if (i == 0) {
          path.moveTo(wpPos.dx, wpPos.dy);
        } else {
          path.lineTo(wpPos.dx, wpPos.dy);
        }
      }
      canvas.drawPath(path, pathPaint);

      // Gambar titik-titik waypoint dengan label A, B, C...
      for (int i = 0; i < status.waypoints.length; i++) {
        final w = status.waypoints[i];
        final wpPos = center + latLngToLocal(w.lat, w.lng, refLat, refLng);
        final isTarget = status.isPlaying && status.currentWaypointIndex == i;

        final wpPaint = Paint()
          ..color = isTarget ? AppTheme.accentGold : AppTheme.primaryGreen
          ..style = PaintingStyle.fill;
        canvas.drawCircle(wpPos, 10 * zoom, wpPaint);

        final outlinePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * zoom;
        canvas.drawCircle(wpPos, 10 * zoom, outlinePaint);

        final label = String.fromCharCode(65 + (i % 26));
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isTarget ? Colors.black : Colors.white,
              fontSize: 11 * zoom,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          wpPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }

    // Gambar Rover (Panah Berwarna Orange/Emas yang berotasi)
    canvas.save();
    canvas.translate(roverPos.dx, roverPos.dy);
    canvas.rotate(status.heading * pi / 180);

    final roverPath = Path()
      ..moveTo(0, -15 * zoom) // Ujung depan
      ..lineTo(10 * zoom, 15 * zoom) // Kanan bawah
      ..lineTo(0, 5 * zoom) // Tengah bawah (lekukan panah)
      ..lineTo(-10 * zoom, 15 * zoom) // Kiri bawah
      ..close();

    final roverPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;
      
    final roverOutlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(roverPath, roverPaint);
    canvas.drawPath(roverPath, roverOutlinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GridMapPainter oldDelegate) {
    return status != oldDelegate.status || 
           panOffset != oldDelegate.panOffset || 
           zoom != oldDelegate.zoom ||
           ikutiRover != oldDelegate.ikutiRover;
  }
}
