import 'dart:convert';
import 'dart:io';

import '../app_version.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseUrl;
  final String? downloadUrl;
  final bool isNewer;

  UpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.isNewer,
  });
}

/// Sprawdza najnowsze wydanie na GitHub. Wywoływane WYŁĄCZNIE na wyraźne
/// żądanie użytkownika (przycisk "Sprawdź aktualizacje") - aplikacja nigdy
/// nie robi tego automatycznie ani w tle, zgodnie z zasadą braku ukrytej
/// komunikacji z internetem.
class UpdateChecker {
  Future<UpdateInfo> checkForUpdate() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$kGithubRepo/releases/latest',
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'CopyPasteClone-UpdateChecker');
      request.headers.set('Accept', 'application/vnd.github+json');

      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'Nie udało się pobrać informacji o wydaniach (kod ${response.statusCode}). '
          'Sprawdź czy repozytorium w app_version.dart jest poprawne i publiczne.',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      final releaseUrl = json['html_url'] as String? ?? '';

      String? downloadUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().contains('portable') && name.endsWith('.zip')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      return UpdateInfo(
        latestVersion: tagName,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl,
        isNewer: _isNewerVersion(tagName, kAppVersion),
      );
    } finally {
      client.close();
    }
  }

  bool _isNewerVersion(String remote, String local) {
    List<int> parse(String v) => v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final r = parse(remote);
    final l = parse(local);

    for (var i = 0; i < r.length || i < l.length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }
}
