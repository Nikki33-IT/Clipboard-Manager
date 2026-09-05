import 'package:flutter_test/flutter_test.dart';
import 'package:clipvault/domain/localization/app_strings.dart';
import 'package:clipvault/settings/app_settings.dart';

void main() {
  test('defaults keep a 500 item limit', () {
    final settings = AppSettings.defaults();
    expect(settings.historyLimit, 500);
  });

  test('defaults are English', () {
    expect(AppSettings.defaults().language, AppLanguage.english);
  });

  test('JSON round-trip preserves values', () {
    final settings = AppSettings.defaults().copyWith(
      historyLimit: () => 100,
      themeMode: ThemeModeSetting.dark,
      globalShortcut: 'Ctrl+Shift+X',
      accentSeed: 0xFFF44336,
      language: AppLanguage.polish,
      retentionPeriod: () => const Duration(days: 7),
      excludedApps: const ['notepad.exe'],
      closeToTray: false,
      startMinimized: true,
      alwaysOnTop: true,
      showCopyToast: false,
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.historyLimit, 100);
    expect(restored.themeMode, ThemeModeSetting.dark);
    expect(restored.globalShortcut, 'Ctrl+Shift+X');
    expect(restored.accentSeed, 0xFFF44336);
    expect(restored.language, AppLanguage.polish);
    expect(restored.retentionPeriod, const Duration(days: 7));
    expect(restored.excludedApps, ['notepad.exe']);
    expect(restored.closeToTray, isFalse);
    expect(restored.startMinimized, isTrue);
    expect(restored.alwaysOnTop, isTrue);
    expect(restored.showCopyToast, isFalse);
  });

  test('missing language falls back to English', () {
    final restored = AppSettings.fromJson({});
    expect(restored.language, AppLanguage.english);
  });

  test('null limit (no limit) is preserved', () {
    final settings =
        AppSettings.defaults().copyWith(historyLimit: () => null);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.historyLimit, isNull);
  });

  test('both locales expose all key strings', () {
    final en = EnStrings();
    final pl = PlStrings();
    expect(en.itemsLabel(1), '1 entry');
    expect(en.itemsLabel(5), '5 entries');
    expect(pl.itemsLabel(1), isNotEmpty);
    expect(pl.itemsLabel(5), isNotEmpty);
    expect(en.trayQuit, isNotEmpty);
    expect(pl.trayQuit, isNotEmpty);
    expect(en.dateLabel(2026, 9, 5), 'Sep 5, 2026');
    expect(pl.dateLabel(2026, 9, 5), isNotEmpty);
  });
}
