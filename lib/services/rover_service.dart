import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rover_status.dart';

/// Kontrak komunikasi dengan rover. UI (screens/widgets) HANYA bicara ke
/// interface ini, tidak pernah tahu apakah datanya dari simulasi atau
/// Bluetooth/LoRa asli.
///
/// Perintah yang dikirim (sesuai protokol yang sudah didefinisikan):
///   F, B, L, R, S       - gerak diskret (maju/mundur/kiri/kanan/stop)
///   REC:1, REC:0        - mulai/stop rekam
///   MARK                - tandai posisi+heading SEKARANG jadi waypoint
///   UNMARK_LAST         - batalkan waypoint TERAKHIR yang ditandai
///   CLEAR_WAYPOINTS     - hapus SEMUA waypoint (reset misi)
///   PLAY                - jalankan hasil rekaman (mode autonomous)
///   MODE:M, MODE:A      - ganti mode manual/autonomous
///
/// CATATAN: MARK, UNMARK_LAST, CLEAR_WAYPOINTS belum ada di dokumen
/// protokol LoRa lama -- perlu ditambahkan ke firmware remote saat
/// integrasi nanti.
///
/// PENTING soal MARK: firmware rover perlu balas konfirmasi berisi
/// lat/lng/heading SAAT itu (bukan cuma "OK") supaya waypoint yang
/// tersimpan di app benar-benar posisi rover sungguhan, bukan tebakan
/// dari status terakhir yang mungkin sudah agak basi.
abstract class RoverService {
  Stream<RoverStatus> get statusStream;
  RoverStatus get currentStatus;
  void sendCommand(String command);
  void dispose();
}

/// Implementasi SIMULASI untuk pengembangan UI sebelum LoRa siap.
/// Rover virtual bergerak sesuai perintah yang dikirim, supaya alur
/// interaksi (tekan tombol -> lihat perubahan di peta) bisa diuji utuh
/// tanpa hardware. Waypoint disimpan otomatis ke penyimpanan lokal HP,
/// jadi tetap ada walau app ditutup/restart.
class MockRoverService implements RoverService {
  RoverStatus _status = RoverStatus.initial().copyWith(
    connected: true,
    satellites: 9,
  );

  final _controller = StreamController<RoverStatus>.broadcast();
  Timer? _heartbeat;

  /// Timer untuk animasi misi autonomous (PLAY).
  Timer? _timerMisi;

  static const double _langkahMeter = 0.6; // simulasi jarak per tekan tombol
  static const double _langkahDerajat = 15; // simulasi sudut per tekan tombol
  static const _kunciSimpanMisi = 'senagarda_waypoints_v1';

  /// Kecepatan simulasi: jarak yang ditempuh per tick animasi (meter).
  /// Disesuaikan supaya terlihat realistis di peta -- ~1m per 200ms
  /// → ~5m/s, agak cepat tapi enak dilihat di simulasi.
  static const double _kecepatanMisi = 1.0;

  /// Jarak (meter) yang dianggap "sudah sampai" di waypoint target.
  /// Agak longgar supaya simulasi tidak stuck di satu titik karena
  /// overshoot aritmatika floating-point.
  static const double _toleransiSampai = 1.5;

  MockRoverService() {
    _muatMisiTersimpan();
    // Kirim status berkala (meniru status berkala dari LoRa nanti),
    // supaya UI yang subscribe stream selalu dapat data terbaru.
    _heartbeat = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _controller.add(_status);
    });
  }

  // --- Penyimpanan lokal (SharedPreferences) ---

  Future<void> _muatMisiTersimpan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kunciSimpanMisi);
      if (raw == null) return; // belum pernah simpan misi -> mulai kosong
      final daftar = (jsonDecode(raw) as List)
          .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
          .toList();
      _status = _status.copyWith(waypoints: daftar);
      _controller.add(_status);
    } catch (_) {
      // Gagal muat (data korup/format lama) -> mulai dari kosong,
      // bukan error fatal.
    }
  }

  Future<void> _simpanMisi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(
        _status.waypoints.map((w) => w.toJson()).toList(),
      );
      await prefs.setString(_kunciSimpanMisi, raw);
    } catch (_) {
      // Gagal simpan -- tidak fatal, cuma berarti waypoint sesi ini
      // mungkin hilang kalau app ditutup. Tidak menghentikan aplikasi.
    }
  }

  @override
  Stream<RoverStatus> get statusStream => _controller.stream;

  @override
  RoverStatus get currentStatus => _status;

  @override
  void sendCommand(String command) {
    switch (command) {
      case 'F':
        _geser(_langkahMeter);
        break;
      case 'B':
        _geser(-_langkahMeter);
        break;
      case 'L':
        _status = _status.copyWith(
          heading: _normalisasi(_status.heading - _langkahDerajat),
        );
        break;
      case 'R':
        _status = _status.copyWith(
          heading: _normalisasi(_status.heading + _langkahDerajat),
        );
        break;
      case 'S':
        // berhenti -- tidak ada perubahan posisi/arah
        break;
      case 'REC:1':
        _status = _status.copyWith(isRecording: true);
        break;
      case 'REC:0':
        _status = _status.copyWith(isRecording: false);
        break;
      case 'MODE:M':
        _hentikanMisi(); // kalau sedang jalan, hentikan dulu
        _status = _status.copyWith(mode: RoverMode.manual);
        break;
      case 'MODE:A':
        _status = _status.copyWith(mode: RoverMode.autonomous);
        break;
      case 'MARK':
        // Tandai posisi & arah SEKARANG sebagai waypoint (biasanya
        // ditekan operator saat rover di ujung sawah / titik belok).
        final titik = Waypoint(
          lat: _status.lat,
          lng: _status.lng,
          heading: _status.heading,
          waktu: DateTime.now(),
        );
        _status = _status.copyWith(
          waypoints: [..._status.waypoints, titik],
        );
        _simpanMisi();
        break;
      case 'UNMARK_LAST':
        // Batalkan waypoint TERAKHIR (koreksi cepat kalau salah tandai).
        if (_status.waypoints.isNotEmpty) {
          final daftar = [..._status.waypoints]..removeLast();
          _status = _status.copyWith(waypoints: daftar);
          _simpanMisi();
        }
        break;
      case 'CLEAR_WAYPOINTS':
        // Hapus SEMUA waypoint -- dipanggil setelah operator konfirmasi
        // di dialog (lihat _konfirmasiHapusSemua di home_screen.dart).
        _hentikanMisi();
        _status = _status.copyWith(waypoints: []);
        _simpanMisi();
        break;
      case 'PLAY':
        _mulaiMisi();
        break;
      case 'STOP_AUTO':
        _hentikanMisi();
        break;
      case 'KALIBRASI_ARAH':
        // Simulasi: tidak ada efek khusus, cuma terima perintah.
        break;
      default:
        break;
    }
    _controller.add(_status);
  }

  // --- Simulasi misi autonomous (PLAY) ---

  /// Mulai jalankan misi: rover bergerak otomatis dari waypoint ke
  /// waypoint, heading menghadap ke tujuan, posisi diperbarui tiap tick.
  void _mulaiMisi() {
    if (_status.waypoints.isEmpty) return; // tidak ada jalur
    if (_status.isPlaying) return; // sudah jalan

    _status = _status.copyWith(
      isPlaying: true,
      currentWaypointIndex: 0,
      mode: RoverMode.autonomous,
    );
    _controller.add(_status);

    // Tick animasi tiap 200ms -- cukup halus utk terlihat bergerak
    // di peta tanpa terlalu boros CPU.
    _timerMisi = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _tickMisi();
    });
  }

  /// Satu langkah animasi misi: gerakkan rover mendekat ke waypoint
  /// target saat ini. Kalau sudah sampai, pindah ke waypoint berikutnya.
  /// Kalau semua waypoint sudah dilalui, misi selesai.
  void _tickMisi() {
    final idx = _status.currentWaypointIndex;
    if (idx < 0 || idx >= _status.waypoints.length) {
      _hentikanMisi();
      return;
    }

    final target = _status.waypoints[idx];
    final jarak = _hitungJarak(
      _status.lat, _status.lng, target.lat, target.lng,
    );

    if (jarak < _toleransiSampai) {
      // Sudah sampai di waypoint ini — lanjut ke berikutnya
      final idxBerikutnya = idx + 1;
      if (idxBerikutnya >= _status.waypoints.length) {
        // Semua waypoint sudah dilalui — misi selesai!
        _hentikanMisi();
        return;
      }
      _status = _status.copyWith(currentWaypointIndex: idxBerikutnya);
      _controller.add(_status);
      return;
    }

    // Hitung heading ke waypoint target
    final headingKeTarget = _hitungHeading(
      _status.lat, _status.lng, target.lat, target.lng,
    );

    // Geser rover ke arah target
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * cos(_status.lat * pi / 180);
    final headingRad = headingKeTarget * pi / 180;

    // Jangan overshoot — batasi langkah ke jarak sisa
    final langkah = jarak < _kecepatanMisi ? jarak : _kecepatanMisi;
    final dLat = (langkah * cos(headingRad)) / metersPerDegreeLat;
    final dLng = (langkah * sin(headingRad)) / metersPerDegreeLng;

    _status = _status.copyWith(
      lat: _status.lat + dLat,
      lng: _status.lng + dLng,
      heading: _normalisasi(headingKeTarget),
    );
    _controller.add(_status);
  }

  /// Hentikan misi autonomous (entah karena selesai atau operator tekan
  /// STOP_AUTO). Reset state playback tapi PERTAHANKAN waypoint.
  void _hentikanMisi() {
    _timerMisi?.cancel();
    _timerMisi = null;
    _status = _status.copyWith(
      isPlaying: false,
      currentWaypointIndex: -1,
    );
    _controller.add(_status);
  }

  /// Hitung jarak antara dua titik koordinat (meter), pakai pendekatan
  /// bumi datar lokal (Euclidean) -- cukup akurat untuk jarak pendek
  /// (<1km) seperti pemakaian di sawah.
  double _hitungJarak(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * cos(lat1 * pi / 180);
    final dLat = (lat2 - lat1) * metersPerDegreeLat;
    final dLng = (lng2 - lng1) * metersPerDegreeLng;
    return sqrt(dLat * dLat + dLng * dLng);
  }

  /// Hitung heading (derajat, 0=utara, 90=timur) dari titik asal ke
  /// titik tujuan.
  double _hitungHeading(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * cos(lat1 * pi / 180);
    final dLat = (lat2 - lat1) * metersPerDegreeLat;
    final dLng = (lng2 - lng1) * metersPerDegreeLng;
    final rad = atan2(dLng, dLat); // atan2(x, y) karena 0° = utara
    return _normalisasi(rad * 180 / pi);
  }

  /// Geser posisi simulasi sejauh [meter] ke arah heading saat ini.
  /// Konversi meter -> derajat lat/lng pakai pendekatan bumi datar lokal
  /// (cukup akurat untuk simulasi jarak pendek).
  void _geser(double meter) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * cos(_status.lat * pi / 180);
    final headingRad = _status.heading * pi / 180;

    final dLat = (meter * cos(headingRad)) / metersPerDegreeLat;
    final dLng = (meter * sin(headingRad)) / metersPerDegreeLng;

    _status = _status.copyWith(
      lat: _status.lat + dLat,
      lng: _status.lng + dLng,
    );
  }

  double _normalisasi(double derajat) {
    var d = derajat % 360;
    if (d < 0) d += 360;
    return d;
  }

  @override
  void dispose() {
    _timerMisi?.cancel();
    _heartbeat?.cancel();
    _controller.close();
  }
}

