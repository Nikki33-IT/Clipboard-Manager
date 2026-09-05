import 'package:flutter_test/flutter_test.dart';
import 'package:clipvault/settings/app_settings.dart';

void main() {
  test('domyślne ustawienia mają limit 500', () {
    final settings = AppSettings.defaults();
    expect(settings.historyLimit, 500);
  });

  test('round-trip JSON zachowuje wartości', () {
    final settings = AppSettings.defaults().copyWith(
      historyLimit: () => 100,
      themeMode: ThemeModeSetting.dark,
      globalShortcut: 'Ctrl+Shift+X',
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.historyLimit, 100);
    expect(restored.themeMode, ThemeModeSetting.dark);
    expect(restored.globalShortcut, 'Ctrl+Shift+X');
  });

  test('brak limitu (null) jest zachowywany', () {
    final settings =
        AppSettings.defaults().copyWith(historyLimit: () => null);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.historyLimit, isNull);
  });
}
