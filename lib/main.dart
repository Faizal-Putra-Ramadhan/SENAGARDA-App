import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  // Aplikasi kontrol peta (gaya DJI/XAG) lebih nyaman dipakai landscape --
  // peta dapat ruang lebih lebar, dan HP biasanya dipegang dua tangan
  // dengan D-pad di kanan-kiri saat mengendalikan rover.
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    debugPrint('[SENAGARDA] Supabase init gagal (mungkin offline): $e');
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
