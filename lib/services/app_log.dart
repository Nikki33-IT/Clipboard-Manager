import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Minimal file logger for diagnostics.
///
/// Release builds have no console, so this file is the only trace of
/// startup errors (e.g. a dead tray). Path: %APPDATA%/com.example/ClipVault/clipvault.log
class AppLog {
  static Future<String> get filePath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'clipvault.log');
  }

  static Future<void> write(String message) async {
    try {
      final file = File(await filePath);
      if (await file.exists() && await file.length() > 256 * 1024) {
        await file.writeAsString(''); // simple rotation: never grow forever
      }
      await file.writeAsString(
        '[${DateTime.now().toIso8601String()}] $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // The logger must never crash the app.
    }
  }
}
