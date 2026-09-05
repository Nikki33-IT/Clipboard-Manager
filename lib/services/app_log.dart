import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Minimalny logger plikowy do diagnostyki.
///
/// Wersja release nie ma konsoli, wiec jedyny slad po bledach startu
/// (np. martwy tray) to ten plik. Sciezka: %APPDATA%/com.example/ClipVault/clipvault.log
class AppLog {
  static Future<String> get filePath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'clipvault.log');
  }

  static Future<void> write(String message) async {
    try {
      final file = File(await filePath);
      if (await file.exists() && await file.length() > 256 * 1024) {
        await file.writeAsString(''); // prosta rotacja: nie rosniemy w nieskonczonosc
      }
      await file.writeAsString(
        '[${DateTime.now().toIso8601String()}] $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Logger nigdy nie moze wywalic aplikacji.
    }
  }
}
