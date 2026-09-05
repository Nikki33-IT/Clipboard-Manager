/// Application language. English is the default; Polish is opt-in
/// via Settings -> Appearance -> Language.
enum AppLanguage { english, polish }

/// Every user-facing string in one place. UI reads these through
/// `stringsProvider`, so switching language repaints the whole app.
abstract class AppStrings {
  // Top bar
  String get appName;
  String get historyEmptyLabel;
  String itemsLabel(int count);
  String get settingsTooltip;
  String get closeSettingsTooltip;

  // History screen
  String get searchHint;
  String get clearSearchTooltip;
  String get filterAll;
  String get filterPinned;
  String get filterLinks;
  String get filterEmails;
  String get filterText;
  String historyCount(int total);
  String resultsCount(int shown, int total);
  String get emptyTitle;
  String get emptySubtitle;
  String get emptyShortcutHint;
  String get noResultsTitle;
  String get noResultsSubtitle;
  String get clearFilters;
  String get copiedToast;

  // History groups
  String get groupPinned;
  String get groupToday;
  String get groupYesterday;
  String dateLabel(int year, int month, int day);

  // Clip tile
  String get typeLink;
  String get typeEmail;
  String get typeNote;
  String get typeImage;
  String get typeHtml;
  String get typeRtf;
  String get typeText;
  String typeFiles(int count);
  String get hiddenSecret;
  String get justNow;
  String minutesAgo(int n);
  String hoursAgo(int n);
  String get yesterday;
  String get pinTooltip;
  String get unpinTooltip;
  String get deleteTooltip;

  // Settings screen
  String get settingsTitle;
  String get historyCard;
  String get limitLabel;
  String get limitUnlimited;
  String get autoCleanup;
  String get retentionLabel;
  String get retentionUnlimited;
  String get retention1Day;
  String get retention7Days;
  String get retention30Days;
  String get imagesLabel;
  String get imagesSubtitle;
  String get generalCard;
  String get autostartLabel;
  String get monitoringLabel;
  String get closeToTrayLabel;
  String get closeToTraySubtitle;
  String get startMinimizedLabel;
  String get alwaysOnTopLabel;
  String get copyToastLabel;
  String get shortcutLabel;
  String get appearanceCard;
  String get themeLight;
  String get themeDark;
  String get themeSystem;
  String get accentLabel;
  String get languageLabel;
  String get privacyCard;
  String get saveSecretsLabel;
  String get saveSecretsSubtitle;
  String excludedLabel(int count);
  String get editButton;
  String get dataCard;
  String get exportJson;
  String get importJson;
  String get restoreDefaults;
  String get restoreDefaultsConfirm;
  String get aboutCard;
  String get versionLabel;
  String get checkUpdates;
  String get authorLabel;
  String get githubButton;

  // Dialogs & snackbars
  String get ok;
  String get cancel;
  String get continueButton;
  String get saveButton;
  String get addTooltip;
  String get checkingUpdates;
  String get updateErrorTitle;
  String get upToDateTitle;
  String get upToDateBody;
  String get updateAvailableTitle;
  String updateAvailableBody(String latest, String current);
  String get laterButton;
  String get updateButton;
  String get openReleasePage;
  String missingUpdateScript(String path);
  String get exportWarning;
  String exportedTo(String path);
  String importMissing(String path);
  String get importedOk;
  String get importError;
  String get shortcutDialogTitle;
  String get shortcutHoldHint;
  String get shortcutPressHint;
  String shortcutChanged(String shortcut);
  String get excludedDialogTitle;
  String get excludedHint;
  String get noExclusions;
  String updateFetchError(int code);

  // Tray menu
  String get trayOpenHistory;
  String trayToggleMonitoring(bool isRunning);
  String get trayClearHistory;
  String get traySettings;
  String get trayQuit;
}

class EnStrings extends AppStrings {
  @override
  String get appName => 'ClipVault';
  @override
  String get historyEmptyLabel => 'Clipboard history';
  @override
  String itemsLabel(int count) => count == 1 ? '1 entry' : '$count entries';
  @override
  String get settingsTooltip => 'Settings';
  @override
  String get closeSettingsTooltip => 'Close settings';

  @override
  String get searchHint => 'Search history…';
  @override
  String get clearSearchTooltip => 'Clear search';
  @override
  String get filterAll => 'All';
  @override
  String get filterPinned => 'Pinned';
  @override
  String get filterLinks => 'Links';
  @override
  String get filterEmails => 'Emails';
  @override
  String get filterText => 'Text';
  @override
  String historyCount(int total) => 'History • $total';
  @override
  String resultsCount(int shown, int total) => 'Results: $shown of $total';
  @override
  String get emptyTitle => 'History is empty';
  @override
  String get emptySubtitle => 'Copy something (Ctrl+C) to see it here.';
  @override
  String get emptyShortcutHint => 'Ctrl+Shift+V — show window';
  @override
  String get noResultsTitle => 'No results';
  @override
  String get noResultsSubtitle => 'Try another phrase or clear filters.';
  @override
  String get clearFilters => 'Clear filters';
  @override
  String get copiedToast => 'Copied to clipboard';

  @override
  String get groupPinned => 'Pinned';
  @override
  String get groupToday => 'Today';
  @override
  String get groupYesterday => 'Yesterday';
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  @override
  String dateLabel(int year, int month, int day) =>
      '${_months[month - 1]} $day, $year';

  @override
  String get typeLink => 'Link';
  @override
  String get typeEmail => 'Email';
  @override
  String get typeNote => 'Note';
  @override
  String get typeImage => 'Image';
  @override
  String get typeHtml => 'HTML';
  @override
  String get typeRtf => 'RTF';
  @override
  String get typeText => 'Text';
  @override
  String typeFiles(int count) => 'Files ($count)';
  @override
  String get hiddenSecret => 'Hidden secret';
  @override
  String get justNow => 'just now';
  @override
  String minutesAgo(int n) => '$n min ago';
  @override
  String hoursAgo(int n) => '$n h ago';
  @override
  String get yesterday => 'yesterday';
  @override
  String get pinTooltip => 'Pin';
  @override
  String get unpinTooltip => 'Unpin';
  @override
  String get deleteTooltip => 'Delete';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get historyCard => 'History';
  @override
  String get limitLabel => 'Item limit';
  @override
  String get limitUnlimited => 'No limit';
  @override
  String get autoCleanup => 'Auto-clean old items';
  @override
  String get retentionLabel => 'Keep entries';
  @override
  String get retentionUnlimited => 'No time limit';
  @override
  String get retention1Day => '1 day';
  @override
  String get retention7Days => '7 days';
  @override
  String get retention30Days => '30 days';
  @override
  String get imagesLabel => 'Save images & files';
  @override
  String get imagesSubtitle => 'Screenshots (PrintScreen) and copied files';
  @override
  String get generalCard => 'General';
  @override
  String get autostartLabel => 'Start with system';
  @override
  String get monitoringLabel => 'Clipboard monitoring on';
  @override
  String get closeToTrayLabel => 'X minimizes to tray';
  @override
  String get closeToTraySubtitle => 'Off: X quits the app like from tray';
  @override
  String get startMinimizedLabel => 'Start minimized to tray';
  @override
  String get alwaysOnTopLabel => 'Always on top';
  @override
  String get copyToastLabel => 'Show copy confirmation';
  @override
  String get shortcutLabel => 'Global shortcut';
  @override
  String get appearanceCard => 'Appearance';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeSystem => 'System';
  @override
  String get accentLabel => 'Accent color';
  @override
  String get languageLabel => 'Language';
  @override
  String get privacyCard => 'Privacy & security';
  @override
  String get saveSecretsLabel => 'Save potential secrets';
  @override
  String get saveSecretsSubtitle =>
      'Detected passwords/tokens are skipped by default';
  @override
  String excludedLabel(int count) => 'Excluded apps ($count)';
  @override
  String get editButton => 'Edit';
  @override
  String get dataCard => 'Data';
  @override
  String get exportJson => 'Export JSON';
  @override
  String get importJson => 'Import JSON';
  @override
  String get restoreDefaults => 'Restore defaults';
  @override
  String get restoreDefaultsConfirm => 'Restore default settings?';
  @override
  String get aboutCard => 'About';
  @override
  String get versionLabel => 'Version';
  @override
  String get checkUpdates => 'Check for updates';
  @override
  String get authorLabel => 'Author';
  @override
  String get githubButton => 'github.com/allynIT';

  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get continueButton => 'Continue';
  @override
  String get saveButton => 'Save';
  @override
  String get addTooltip => 'Add';
  @override
  String get checkingUpdates => 'Checking for updates…';
  @override
  String get updateErrorTitle => 'Update check failed';
  @override
  String get upToDateTitle => 'No updates';
  @override
  String get upToDateBody => 'You already have the latest version.';
  @override
  String get updateAvailableTitle => 'Update available';
  @override
  String updateAvailableBody(String latest, String current) =>
      'Version v$latest is available (you have v$current).\n\n'
      'The app will download the portable package and replace files. '
      'Close the app when asked after clicking "Update".';
  @override
  String get laterButton => 'Later';
  @override
  String get updateButton => 'Update';
  @override
  String get openReleasePage => 'Open release page';
  @override
  String missingUpdateScript(String path) =>
      'update.ps1 not found next to the .exe ($path). '
      'Download the new version manually from the release page.';
  @override
  String get exportWarning =>
      'The export file may contain sensitive info '
      '(e.g. the excluded app list). Continue?';
  @override
  String exportedTo(String path) => 'Exported to: $path';
  @override
  String importMissing(String path) => 'File not found: $path';
  @override
  String get importedOk => 'Settings imported.';
  @override
  String get importError => 'Import error: invalid file.';
  @override
  String get shortcutDialogTitle => 'Change global shortcut';
  @override
  String get shortcutHoldHint => 'Hold Ctrl/Shift/Alt and press a key…';
  @override
  String get shortcutPressHint => 'Press a key combination…';
  @override
  String shortcutChanged(String shortcut) => 'Shortcut set to $shortcut';
  @override
  String get excludedDialogTitle => 'Excluded apps';
  @override
  String get excludedHint => 'e.g. keepass.exe';
  @override
  String get noExclusions => 'No exclusions.';
  @override
  String updateFetchError(int code) =>
      'Failed to fetch releases (code $code). '
      'Check that the repository in app_version.dart is correct and public.';

  @override
  String get trayOpenHistory => 'Open history';
  @override
  String trayToggleMonitoring(bool isRunning) =>
      isRunning ? 'Pause monitoring' : 'Resume monitoring';
  @override
  String get trayClearHistory => 'Clear history';
  @override
  String get traySettings => 'Settings';
  @override
  String get trayQuit => 'Quit app';
}

class PlStrings extends AppStrings {
  @override
  String get appName => 'ClipVault';
  @override
  String get historyEmptyLabel => 'Historia schowka';
  @override
  String itemsLabel(int count) {
    if (count == 1) return '1 wpis';
    final lastTwo = count % 100;
    final last = count % 10;
    if (lastTwo >= 12 && lastTwo <= 14) return '$count wpisów';
    if (last >= 2 && last <= 4) return '$count wpisy';
    return '$count wpisów';
  }

  @override
  String get settingsTooltip => 'Ustawienia';
  @override
  String get closeSettingsTooltip => 'Zamknij ustawienia';

  @override
  String get searchHint => 'Szukaj w historii…';
  @override
  String get clearSearchTooltip => 'Wyczyść wyszukiwanie';
  @override
  String get filterAll => 'Wszystko';
  @override
  String get filterPinned => 'Przypięte';
  @override
  String get filterLinks => 'Linki';
  @override
  String get filterEmails => 'E-maile';
  @override
  String get filterText => 'Tekst';
  @override
  String historyCount(int total) => 'Historia • $total';
  @override
  String resultsCount(int shown, int total) => 'Wyniki: $shown z $total';
  @override
  String get emptyTitle => 'Historia jest pusta';
  @override
  String get emptySubtitle => 'Skopiuj coś (Ctrl+C), żeby zobaczyć to tutaj.';
  @override
  String get emptyShortcutHint => 'Ctrl+Shift+V — pokaż okno';
  @override
  String get noResultsTitle => 'Brak wyników';
  @override
  String get noResultsSubtitle => 'Spróbuj innej frazy albo wyczyść filtry.';
  @override
  String get clearFilters => 'Wyczyść filtry';
  @override
  String get copiedToast => 'Skopiowano do schowka';

  @override
  String get groupPinned => 'Przypięte';
  @override
  String get groupToday => 'Dzisiaj';
  @override
  String get groupYesterday => 'Wczoraj';
  static const _months = [
    'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
    'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
  ];
  @override
  String dateLabel(int year, int month, int day) =>
      '$day ${_months[month - 1]} $year';

  @override
  String get typeLink => 'Link';
  @override
  String get typeEmail => 'E-mail';
  @override
  String get typeNote => 'Notatka';
  @override
  String get typeImage => 'Obraz';
  @override
  String get typeHtml => 'HTML';
  @override
  String get typeRtf => 'RTF';
  @override
  String get typeText => 'Tekst';
  @override
  String typeFiles(int count) => 'Pliki ($count)';
  @override
  String get hiddenSecret => 'Ukryty sekret';
  @override
  String get justNow => 'przed chwilą';
  @override
  String minutesAgo(int n) => '$n min temu';
  @override
  String hoursAgo(int n) => '$n godz. temu';
  @override
  String get yesterday => 'wczoraj';
  @override
  String get pinTooltip => 'Przypnij';
  @override
  String get unpinTooltip => 'Odepnij';
  @override
  String get deleteTooltip => 'Usuń';

  @override
  String get settingsTitle => 'Ustawienia';
  @override
  String get historyCard => 'Historia';
  @override
  String get limitLabel => 'Limit elementów';
  @override
  String get limitUnlimited => 'Bez limitu';
  @override
  String get autoCleanup => 'Automatyczne czyszczenie starych elementów';
  @override
  String get retentionLabel => 'Przechowuj wpisy';
  @override
  String get retentionUnlimited => 'Bez limitu czasu';
  @override
  String get retention1Day => '1 dzień';
  @override
  String get retention7Days => '7 dni';
  @override
  String get retention30Days => '30 dni';
  @override
  String get imagesLabel => 'Zapisuj obrazy i pliki';
  @override
  String get imagesSubtitle => 'Zrzuty ekranu (PrintScreen) i kopiowane pliki';
  @override
  String get generalCard => 'Ogólne';
  @override
  String get autostartLabel => 'Uruchamiaj przy starcie systemu';
  @override
  String get monitoringLabel => 'Monitorowanie schowka aktywne';
  @override
  String get closeToTrayLabel => 'Przycisk X minimalizuje do traya';
  @override
  String get closeToTraySubtitle =>
      'Wyłączone: X zamyka aplikację jak z traya';
  @override
  String get startMinimizedLabel => 'Start zminimalizowany do traya';
  @override
  String get alwaysOnTopLabel => 'Okno zawsze na wierzchu';
  @override
  String get copyToastLabel => 'Pokazuj potwierdzenie kopiowania';
  @override
  String get shortcutLabel => 'Globalny skrót';
  @override
  String get appearanceCard => 'Wygląd';
  @override
  String get themeLight => 'Jasny';
  @override
  String get themeDark => 'Ciemny';
  @override
  String get themeSystem => 'Systemowy';
  @override
  String get accentLabel => 'Kolor akcentu';
  @override
  String get languageLabel => 'Język';
  @override
  String get privacyCard => 'Prywatność i bezpieczeństwo';
  @override
  String get saveSecretsLabel => 'Zapisuj potencjalne sekrety';
  @override
  String get saveSecretsSubtitle =>
      'Domyślnie wykryte hasła/tokeny nie są zapisywane';
  @override
  String excludedLabel(int count) => 'Wykluczone aplikacje ($count)';
  @override
  String get editButton => 'Edytuj';
  @override
  String get dataCard => 'Dane';
  @override
  String get exportJson => 'Eksportuj JSON';
  @override
  String get importJson => 'Importuj JSON';
  @override
  String get restoreDefaults => 'Przywróć ustawienia domyślne';
  @override
  String get restoreDefaultsConfirm => 'Przywrócić domyślne ustawienia?';
  @override
  String get aboutCard => 'O aplikacji';
  @override
  String get versionLabel => 'Wersja';
  @override
  String get checkUpdates => 'Sprawdź aktualizacje';
  @override
  String get authorLabel => 'Autor';
  @override
  String get githubButton => 'github.com/allynIT';

  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Anuluj';
  @override
  String get continueButton => 'Kontynuuj';
  @override
  String get saveButton => 'Zapisz';
  @override
  String get addTooltip => 'Dodaj';
  @override
  String get checkingUpdates => 'Sprawdzanie aktualizacji…';
  @override
  String get updateErrorTitle => 'Błąd sprawdzania aktualizacji';
  @override
  String get upToDateTitle => 'Brak aktualizacji';
  @override
  String get upToDateBody => 'Masz już najnowszą wersję aplikacji.';
  @override
  String get updateAvailableTitle => 'Dostępna aktualizacja';
  @override
  String updateAvailableBody(String latest, String current) =>
      'Nowa wersja v$latest jest dostępna (masz v$current).\n\n'
      'Aplikacja pobierze paczkę portable i podmieni pliki. '
      'Zamknij aplikację po kliknięciu "Aktualizuj", jeśli poprosi.';
  @override
  String get laterButton => 'Później';
  @override
  String get updateButton => 'Aktualizuj';
  @override
  String get openReleasePage => 'Otwórz stronę wydania';
  @override
  String missingUpdateScript(String path) =>
      'Nie znaleziono update.ps1 obok pliku .exe ($path). '
      'Pobierz nową wersję ręcznie ze strony wydania.';
  @override
  String get exportWarning =>
      'Plik eksportu może zawierać poufne informacje '
      '(np. listę wykluczonych aplikacji). Kontynuować?';
  @override
  String exportedTo(String path) => 'Wyeksportowano do: $path';
  @override
  String importMissing(String path) => 'Nie znaleziono pliku: $path';
  @override
  String get importedOk => 'Ustawienia zaimportowane.';
  @override
  String get importError => 'Błąd importu: nieprawidłowy plik.';
  @override
  String get shortcutDialogTitle => 'Zmień globalny skrót';
  @override
  String get shortcutHoldHint => 'Przytrzymaj Ctrl/Shift/Alt i naciśnij klawisz…';
  @override
  String get shortcutPressHint => 'Naciśnij kombinację klawiszy…';
  @override
  String shortcutChanged(String shortcut) => 'Skrót zmieniony na $shortcut';
  @override
  String get excludedDialogTitle => 'Wykluczone aplikacje';
  @override
  String get excludedHint => 'np. keepass.exe';
  @override
  String get noExclusions => 'Brak wykluczeń.';
  @override
  String updateFetchError(int code) =>
      'Nie udało się pobrać informacji o wydaniach (kod $code). '
      'Sprawdź czy repozytorium w app_version.dart jest poprawne i publiczne.';

  @override
  String get trayOpenHistory => 'Otwórz historię';
  @override
  String trayToggleMonitoring(bool isRunning) =>
      isRunning ? 'Wstrzymaj monitorowanie' : 'Wznów monitorowanie';
  @override
  String get trayClearHistory => 'Wyczyść historię';
  @override
  String get traySettings => 'Ustawienia';
  @override
  String get trayQuit => 'Zamknij aplikację';
}
