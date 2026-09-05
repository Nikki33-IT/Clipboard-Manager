import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';

class SettingsRepository {
  Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'settings.json'));
  }

  Future<AppSettings> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return AppSettings.defaults();
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      // Uszkodzony plik ustawień nie może wywalić aplikacji.
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _file;
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<void> resetToDefaults() async {
    await save(AppSettings.defaults());
  }

  /// Eksport do wskazanej ścieżki. Wywołujący (UI) odpowiada za pokazanie
  /// ostrzeżenia o poufności danych przed wywołaniem tej metody.
  Future<void> exportTo(String path, AppSettings settings) async {
    final file = File(path);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  /// Import z walidacją - nigdy nie wykonuje kodu z pliku, tylko parsuje
  /// pola jako dane.
  Future<AppSettings> importFrom(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Nieprawidłowy format pliku ustawień.');
    }
    final settings = AppSettings.fromJson(decoded);
    await save(settings);
    return settings;
  }
}
