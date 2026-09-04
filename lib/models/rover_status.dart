/// Mode operasi rover. Sesuai protokol LoRa: MODE:M (manual) / MODE:A (autonomous).
enum RoverMode { manual, autonomous }

/// Satu titik yang ditandai operator (biasanya di ujung sawah / tempat
/// belok) selama proses rekam misi. BUKAN posisi kontinu -- cuma titik
/// penting yang sengaja disimpan lewat tombol "Tandai Titik".
class Waypoint {
  final double lat;
  final double lng;
  final double heading;
  final DateTime waktu;
  final String? label; // opsional, mis. "Ujung sawah 1" -- bisa diisi nanti

  const Waypoint({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.waktu,
    this.label,
  });

  // Serialisasi untuk simpan lokal (SharedPreferences, format JSON).
  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'heading': heading,
    'waktu': waktu.toIso8601String(),
    'label': label,
  };

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    heading: (json['heading'] as num).toDouble(),
    waktu: DateTime.parse(json['waktu'] as String),
    label: json['label'] as String?,
  );
}

/// Snapshot status rover pada satu titik waktu. Bentuknya mengikuti
/// protokol status LoRa yang sudah didefinisikan:
///   "ST:mode,heading,lat,lng,sats,rec"
class RoverStatus {
  final bool connected;
  final RoverMode mode;
  final double heading; // derajat, 0-359.9 (relatif terhadap arah awal rover)
  final double lat;
  final double lng;
  final int satellites;
  final bool isRecording;
  final List<Waypoint> waypoints;

  /// true selama rover sedang menjalankan misi autonomous (dari PLAY
  /// sampai selesai/dihentikan). Dipakai UI untuk menampilkan progres
  /// dan tombol berhenti.
  final bool isPlaying;

  /// Indeks waypoint yang SEDANG dituju (0-based). -1 kalau tidak sedang
  /// menjalankan misi. Dipakai UI untuk menampilkan "Menuju titik X/Y".
  final int currentWaypointIndex;

  const RoverStatus({
    required this.connected,
    required this.mode,
    required this.heading,
    required this.lat,
    required this.lng,
    required this.satellites,
    required this.isRecording,
    this.waypoints = const [],
    this.isPlaying = false,
    this.currentWaypointIndex = -1,
  });

  /// Titik awal default di sekitar Karangtengah, Imogiri, Bantul.
  factory RoverStatus.initial() {
    return const RoverStatus(
      connected: false,
      mode: RoverMode.manual,
      heading: 0,
      lat: -7.9285,
      lng: 110.3805,
      satellites: 0,
      isRecording: false,
      waypoints: [],
      isPlaying: false,
      currentWaypointIndex: -1,
    );
  }

  RoverStatus copyWith({
    bool? connected,
    RoverMode? mode,
    double? heading,
    double? lat,
    double? lng,
    int? satellites,
    bool? isRecording,
    List<Waypoint>? waypoints,
    bool? isPlaying,
    int? currentWaypointIndex,
  }) {
    return RoverStatus(
      connected: connected ?? this.connected,
      mode: mode ?? this.mode,
      heading: heading ?? this.heading,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      satellites: satellites ?? this.satellites,
      isRecording: isRecording ?? this.isRecording,
      waypoints: waypoints ?? this.waypoints,
      isPlaying: isPlaying ?? this.isPlaying,
      currentWaypointIndex: currentWaypointIndex ?? this.currentWaypointIndex,
    );
  }

  /// Parse dari string protokol "ST:mode,heading,lat,lng,sats,rec"
  /// Dipakai nanti saat RoverService asli (LoRa/Bluetooth) menerima data.
  factory RoverStatus.fromProtocolString(String raw) {
    // raw contoh: "ST:M,45.2,-7.9285,110.3805,8,1"
    final body = raw.startsWith('ST:') ? raw.substring(3) : raw;
    final parts = body.split(',');
    if (parts.length < 6) {
      throw FormatException('Format status tidak lengkap: $raw');
    }
    return RoverStatus(
      connected: true,
      mode: parts[0].trim().toUpperCase() == 'A'
          ? RoverMode.autonomous
          : RoverMode.manual,
      heading: double.tryParse(parts[1]) ?? 0,
      lat: double.tryParse(parts[2]) ?? 0,
      lng: double.tryParse(parts[3]) ?? 0,
      satellites: int.tryParse(parts[4]) ?? 0,
      isRecording: parts[5].trim() == '1',
    );
  }
}
