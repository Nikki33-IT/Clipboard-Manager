enum ThemeModeSetting { light, dark, system }

class AppSettings {
  final int? historyLimit;
  final Duration? retentionPeriod;
  final bool launchAtStartup;
  final String globalShortcut;
  final ThemeModeSetting themeMode;
  final bool monitoringEnabled;
  final bool imagesEnabled;
  final bool saveSecrets;
  final List<String> excludedApps;
  final bool autoCleanupEnabled;

  const AppSettings({
    this.historyLimit = 500,
    this.retentionPeriod,
    this.launchAtStartup = false,
    this.globalShortcut = 'Ctrl+Shift+V',
    this.themeMode = ThemeModeSetting.system,
    this.monitoringEnabled = true,
    this.imagesEnabled = false,
    this.saveSecrets = false,
    this.excludedApps = const ['KeePass', 'Bitwarden', 'cmd.exe', 'powershell.exe', 'WindowsTerminal.exe'],
    this.autoCleanupEnabled = false,
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
    bool? monitoringEnabled,
    bool? imagesEnabled,
    bool? saveSecrets,
    List<String>? excludedApps,
    bool? autoCleanupEnabled,
  }) {
    return AppSettings(
      historyLimit: historyLimit != null ? historyLimit() : this.historyLimit,
      retentionPeriod: retentionPeriod != null ? retentionPeriod() : this.retentionPeriod,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      globalShortcut: globalShortcut ?? this.globalShortcut,
      themeMode: themeMode ?? this.themeMode,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      imagesEnabled: imagesEnabled ?? this.imagesEnabled,
      saveSecrets: saveSecrets ?? this.saveSecrets,
      excludedApps: excludedApps ?? this.excludedApps,
      autoCleanupEnabled: autoCleanupEnabled ?? this.autoCleanupEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'historyLimit': historyLimit,
        'retentionPeriodMinutes': retentionPeriod?.inMinutes,
        'launchAtStartup': launchAtStartup,
        'globalShortcut': globalShortcut,
        'themeMode': themeMode.name,
        'monitoringEnabled': monitoringEnabled,
        'imagesEnabled': imagesEnabled,
        'saveSecrets': saveSecrets,
        'excludedApps': excludedApps,
        'autoCleanupEnabled': autoCleanupEnabled,
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
        monitoringEnabled: json['monitoringEnabled'] as bool? ?? true,
        imagesEnabled: json['imagesEnabled'] as bool? ?? false,
        saveSecrets: json['saveSecrets'] as bool? ?? false,
        excludedApps: (json['excludedApps'] as List?)?.cast<String>() ??
            const ['KeePass', 'Bitwarden', 'cmd.exe', 'powershell.exe', 'WindowsTerminal.exe'],
        autoCleanupEnabled: json['autoCleanupEnabled'] as bool? ?? false,
      );

  factory AppSettings.defaults() => const AppSettings();
}
