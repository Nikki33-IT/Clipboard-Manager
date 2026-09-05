enum ThemeModeSetting { light, dark, system }

class AppSettings {
  final int? historyLimit;
  final Duration? retentionPeriod;
  final bool launchAtStartup;
  final String globalShortcut;
  final ThemeModeSetting themeMode;
  final int accentSeed;
  final bool monitoringEnabled;
  final bool imagesEnabled;
  final bool saveSecrets;
  final List<String> excludedApps;
  final bool autoCleanupEnabled;
  final bool closeToTray;
  final bool startMinimized;
  final bool alwaysOnTop;
  final bool showCopyToast;

  const AppSettings({
    this.historyLimit = 500,
    this.retentionPeriod,
    this.launchAtStartup = false,
    this.globalShortcut = 'Ctrl+Shift+V',
    this.themeMode = ThemeModeSetting.system,
    this.accentSeed = 0xFF5B67F1,
    this.monitoringEnabled = true,
    this.imagesEnabled = false,
    this.saveSecrets = false,
    this.excludedApps = const ['KeePass', 'Bitwarden', 'cmd.exe', 'powershell.exe', 'WindowsTerminal.exe'],
    this.autoCleanupEnabled = false,
    this.closeToTray = true,
    this.startMinimized = false,
    this.alwaysOnTop = false,
    this.showCopyToast = true,
  });

  /// Zwraca NOWY obiekt z podmienionymi polami. Kluczowe: nigdy nie mutujemy
  /// istniejącej instancji w miejscu, bo Riverpod porównuje referencje/wartości
  /// i pominąłby powiadomienie słuchaczy przy mutacji tego samego obiektu.
  AppSettings copyWith({
    int? Function()? historyLimit,
    Duration? Function()? retentionPeriod,
    bool? launchAtStartup,
    String? globalShortcut,
    ThemeModeSetting? themeMode,
    int? accentSeed,
    bool? monitoringEnabled,
    bool? imagesEnabled,
    bool? saveSecrets,
    List<String>? excludedApps,
    bool? autoCleanupEnabled,
    bool? closeToTray,
    bool? startMinimized,
    bool? alwaysOnTop,
    bool? showCopyToast,
  }) {
    return AppSettings(
      historyLimit: historyLimit != null ? historyLimit() : this.historyLimit,
      retentionPeriod: retentionPeriod != null ? retentionPeriod() : this.retentionPeriod,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      globalShortcut: globalShortcut ?? this.globalShortcut,
      themeMode: themeMode ?? this.themeMode,
      accentSeed: accentSeed ?? this.accentSeed,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      imagesEnabled: imagesEnabled ?? this.imagesEnabled,
      saveSecrets: saveSecrets ?? this.saveSecrets,
      excludedApps: excludedApps ?? this.excludedApps,
      autoCleanupEnabled: autoCleanupEnabled ?? this.autoCleanupEnabled,
      closeToTray: closeToTray ?? this.closeToTray,
      startMinimized: startMinimized ?? this.startMinimized,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      showCopyToast: showCopyToast ?? this.showCopyToast,
    );
  }

  Map<String, dynamic> toJson() => {
        'historyLimit': historyLimit,
        'retentionPeriodMinutes': retentionPeriod?.inMinutes,
        'launchAtStartup': launchAtStartup,
        'globalShortcut': globalShortcut,
        'themeMode': themeMode.name,
        'accentSeed': accentSeed,
        'monitoringEnabled': monitoringEnabled,
        'imagesEnabled': imagesEnabled,
        'saveSecrets': saveSecrets,
        'excludedApps': excludedApps,
        'autoCleanupEnabled': autoCleanupEnabled,
        'closeToTray': closeToTray,
        'startMinimized': startMinimized,
        'alwaysOnTop': alwaysOnTop,
        'showCopyToast': showCopyToast,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        historyLimit: json['historyLimit'] as int?,
        retentionPeriod: json['retentionPeriodMinutes'] != null
            ? Duration(minutes: json['retentionPeriodMinutes'] as int)
            : null,
        launchAtStartup: json['launchAtStartup'] as bool? ?? false,
        globalShortcut: json['globalShortcut'] as String? ?? 'Ctrl+Shift+V',
        themeMode: ThemeModeSetting.values.firstWhere(
          (t) => t.name == json['themeMode'],
          orElse: () => ThemeModeSetting.system,
        ),
        accentSeed: json['accentSeed'] as int? ?? 0xFF5B67F1,
        monitoringEnabled: json['monitoringEnabled'] as bool? ?? true,
        imagesEnabled: json['imagesEnabled'] as bool? ?? false,
        saveSecrets: json['saveSecrets'] as bool? ?? false,
        excludedApps: (json['excludedApps'] as List?)?.cast<String>() ??
            const ['KeePass', 'Bitwarden', 'cmd.exe', 'powershell.exe', 'WindowsTerminal.exe'],
        autoCleanupEnabled: json['autoCleanupEnabled'] as bool? ?? false,
        closeToTray: json['closeToTray'] as bool? ?? true,
        startMinimized: json['startMinimized'] as bool? ?? false,
        alwaysOnTop: json['alwaysOnTop'] as bool? ?? false,
        showCopyToast: json['showCopyToast'] as bool? ?? true,
      );

  factory AppSettings.defaults() => const AppSettings();
}
