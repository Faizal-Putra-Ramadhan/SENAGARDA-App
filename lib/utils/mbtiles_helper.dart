import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class MbTilesHelper {
  static Future<String> getMbTilesPath() async {
    const String assetPath = 'assets/map/karangtengahMao.mbtiles';
    const String fileName = 'karangtengahMao.mbtiles';
    
    final Directory docDir = await getApplicationDocumentsDirectory();
    final String localPath = '${docDir.path}/$fileName';
    
    final File localFile = File(localPath);
    
    // Salin file dari asset ke storage lokal jika belum ada
    if (!await localFile.exists()) {
      try {
        final ByteData data = await rootBundle.load(assetPath);
        final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await localFile.writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception('Gagal menyalin file MBTiles: $e');
      }
    }
    
    return localPath;
  }
}