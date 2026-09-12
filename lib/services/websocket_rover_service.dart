import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/rover_status.dart';
import 'rover_service.dart';

/// Implementasi RoverService ASLI -- konek ke ESP32 lewat WiFi (rover
/// jadi Access Point) + WebSocket. Rover kirim status berkala, app kirim
/// perintah gerak/mode langsung ke rover secara realtime.
///
/// CATATAN PENTING soal waypoint (MARK/UNMARK_LAST/CLEAR_WAYPOINTS):
/// operasi2 ini TIDAK dikirim ke rover -- dikelola PENUH di app,
/// memakai posisi TERAKHIR yang diketahui dari status rover (field
/// _status.lat/lng/heading, yg diperbarui tiap terima "ST:..." dari
/// rover). Rover baru butuh tahu daftar waypoint saat "PLAY" ditekan --
/// baru saat itu SELURUH daftar dikirim sekaligus ke rover.
class WebSocketRoverService implements RoverService {
  final String espIpAddress;
  final int port;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  RoverStatus _status = RoverStatus.initial();
  final _controller = StreamController<RoverStatus>.broadcast();
  Timer? _cekFailsafe;
  DateTime _terakhirTerimaStatus = DateTime.now();

  static const _kunciSimpanMisi = 'senagarda_waypoints_v1';

  WebSocketRoverService({
    this.espIpAddress = '192.168.0.250', // IP statis ESP32 di mode Station (ubah jika gateway WIFI A berbeda)
    this.port = 80, // AsyncWebServer
  });

  /// Sambungkan ke rover. Lempar exception kalau gagal -- caller (layar
  /// Connect) yang urus tampilan error/loading.
  Future<void> connect() async {
    await _muatMisiTersimpan();

    final uri = Uri.parse('ws://$espIpAddress:$port/ws'); // path /ws wajib (AsyncWebSocket)
    _channel = WebSocketChannel.connect(uri);

    // Tunggu koneksi benar2 siap (ready future) -- kalau gagal, ini yg
    // melempar exception ke caller.
    await _channel!.ready;

    _subscription = _channel!.stream.listen(
      _tanganiPesanMasuk,
      onError: (_) => _tandaiTerputus(),
      onDone: () => _tandaiTerputus(),
    );

    // Cek berkala: kalau lama tidak ada status masuk, tandai terputus.
    // Failsafe SISI APP -- rover sendiri juga failsafe gerak kalau
    // koneksi putus (lihat firmware).
    _cekFailsafe = Timer.periodic(const Duration(seconds: 2), (_) {
      final diam = DateTime.now().difference(_terakhirTerimaStatus);
      if (diam.inSeconds > 3 && _status.connected) {
        _tandaiTerputus();
      }
    });
  }

  void _tanganiPesanMasuk(dynamic pesan) {
    final teks = pesan.toString();
    if (teks.startsWith('ST:')) {
      try {
        final baru = RoverStatus.fromProtocolString(teks);
        // Waypoint TIDAK datang dari rover -- pertahankan yg sudah ada di app.
        // PENTING: Pertahankan juga isPlaying dan currentWaypointIndex karena
        // rover tidak mengirim state misi tersebut di protokol LoRa lama.
        _status = baru.copyWith(
          waypoints: _status.waypoints,
          isPlaying: _status.isPlaying,
          currentWaypointIndex: _status.currentWaypointIndex,
        );
        _terakhirTerimaStatus = DateTime.now();
        _controller.add(_status);
      } catch (_) {
        // format tidak dikenal -- abaikan, jangan crash
      }
    }
  }

  void _tandaiTerputus() {
    _status = _status.copyWith(connected: false);
    _controller.add(_status);
  }

  // --- Penyimpanan lokal waypoint (SAMA seperti MockRoverService) ---

  Future<void> _muatMisiTersimpan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kunciSimpanMisi);
      if (raw == null) return;
      final daftar = (jsonDecode(raw) as List)
          .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
          .toList();
      _status = _status.copyWith(waypoints: daftar);
    } catch (_) {}
  }

  Future<void> _simpanMisi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(
        _status.waypoints.map((w) => w.toJson()).toList(),
      );
      await prefs.setString(_kunciSimpanMisi, raw);
    } catch (_) {}
  }

  @override
  Stream<RoverStatus> get statusStream => _controller.stream;

  @override
  RoverStatus get currentStatus => _status;

  @override
  void sendCommand(String command) {
    switch (command) {
      case 'MARK':
        final titik = Waypoint(
          lat: _status.lat,
          lng: _status.lng,
          heading: _status.heading,
          waktu: DateTime.now(),
        );
        _status = _status.copyWith(waypoints: [..._status.waypoints, titik]);
        _controller.add(_status);
        _simpanMisi();
        return; // TIDAK dikirim ke rover -- murni operasi app.

      case 'UNMARK_LAST':
        if (_status.waypoints.isNotEmpty) {
          final daftar = [..._status.waypoints]..removeLast();
          _status = _status.copyWith(waypoints: daftar);
          _controller.add(_status);
          _simpanMisi();
        }
        return;

      case 'CLEAR_WAYPOINTS':
        _status = _status.copyWith(
          waypoints: [],
          isPlaying: false,
          currentWaypointIndex: -1,
        );
        _controller.add(_status);
        _simpanMisi();
        return;

      case 'PLAY':
        if (_status.waypoints.isEmpty) return;
        _status = _status.copyWith(
          isPlaying: true,
          currentWaypointIndex: 0,
        );
        _controller.add(_status);
        // Kirim SELURUH daftar waypoint ke rover sekaligus, format:
        // "PLAY:lat1,lng1|lat2,lng2|..."
        final data = _status.waypoints
            .map((w) => '${w.lat},${w.lng}')
            .join('|');
        _channel?.sink.add('PLAY:$data');
        return;
        
      case 'STOP_AUTO':
        _status = _status.copyWith(
          isPlaying: false,
          currentWaypointIndex: -1,
        );
        _controller.add(_status);
        _channel?.sink.add('STOP_AUTO');
        return;
    }

    // Perintah lain (F, B, L, R, S, REC:1, REC:0, MODE:M, MODE:A)
    // dikirim APA ADANYA ke rover -- protokolnya sudah sama persis.
    _channel?.sink.add(command);
  }

  @override
  void dispose() {
    _cekFailsafe?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
