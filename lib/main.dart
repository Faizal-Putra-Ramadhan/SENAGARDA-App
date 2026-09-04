import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  // Aplikasi kontrol peta (gaya DJI/XAG) lebih nyaman dipakai landscape --
  // peta dapat ruang lebih lebar, dan HP biasanya dipegang dua tangan
  // dengan D-pad di kanan-kiri saat mengendalikan rover.
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Flutter Map Tile Caching (FMTC) --
  // Tile peta yang pernah dimuat saat online akan disimpan di storage HP,
  // sehingga saat di lapangan tanpa internet, peta tetap muncul.
  try {
    await FMTCObjectBoxBackend().initialise();
    final store = FMTCStore('senagarda_map');
    await store.manage.create();
  } catch (e) {
    debugPrint("FMTC Initialization Error: $e");
  }

  // Orientasi tidak dibatasi lagi karena ada layar Dashboard/Trap/Rover
  // yang lebih nyaman dalam portrait.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SenagardaApp());
}

class SenagardaApp extends StatelessWidget {
  const SenagardaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SENAGARDA Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainScreen(),
    );
  }
}
