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
      // A corrupted settings file must never crash the app.
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

  /// Export to the given path. The caller (UI) is responsible for showing
  /// a data-sensitivity warning before calling this method.
  Future<void> exportTo(String path, AppSettings settings) async {
    final file = File(path);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  /// Import with validation - never executes code from the file, only
  /// parses fields as data.
  Future<AppSettings> importFrom(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid settings file format.');
    }
    final settings = AppSettings.fromJson(decoded);
    await save(settings);
    return settings;
  }
}
