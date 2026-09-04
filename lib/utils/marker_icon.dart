import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bikin ikon marker CUSTOM (panah navigasi) secara terprogram lewat
/// Canvas -- tidak perlu file gambar terpisah. Dipakai sebagai ikon
/// rover di peta, gantinya pin default Google Maps yang generik.
///
/// Gambar menghadap ke ATAS (utara/0 derajat). Rotasi visual di peta
/// diatur lewat properti `rotation` pada Marker, BUKAN di gambar ini --
/// jadi cukup satu ikon statis, tidak perlu digambar ulang tiap kali
/// heading berubah.
///
/// KALAU PUNYA FOTO/LOGO ROVER ASLI: ganti isi fungsi ini dengan
/// BitmapDescriptor.fromAssetImage(), lihat komentar di bawah.
Future<BitmapDescriptor> buatIkonPanahRover({
  required Color warnaIsi,
  double ukuran = 120,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final paintIsi = Paint()..color = warnaIsi;
  final paintTepi = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = ukuran * 0.07
    ..strokeJoin = StrokeJoin.round;

  // Segitiga navigasi menghadap ke atas, dengan takik di bagian bawah
  // (bentuk seperti jarum kompas/panah GPS pada umumnya).
  final path = Path()
    ..moveTo(ukuran / 2, ukuran * 0.05) // puncak
    ..lineTo(ukuran * 0.88, ukuran * 0.92) // kanan bawah
    ..lineTo(ukuran / 2, ukuran * 0.72) // takik tengah
    ..lineTo(ukuran * 0.12, ukuran * 0.92) // kiri bawah
    ..close();

  canvas.drawPath(path, paintIsi);
  canvas.drawPath(path, paintTepi);

  final picture = recorder.endRecording();
  final image = await picture.toImage(ukuran.toInt(), ukuran.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}

/// ALTERNATIF -- kalau Anda punya foto/logo rover asli (mis. PNG dengan
/// latar transparan), pakai ini:
///
/// 1. Taruh file di project: assets/images/rover_icon.png
/// 2. Daftarkan di pubspec.yaml:
///      flutter:
///        assets:
///          - assets/images/rover_icon.png
/// 3. Panggil:
///      BitmapDescriptor.fromAssetImage(
///        ImageConfiguration(size: Size(64, 64)),
///        'assets/images/rover_icon.png',
///      )
///    (fungsi ini return Future<BitmapDescriptor>, pakai await)
