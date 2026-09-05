import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_version.dart';
import '../../application/providers.dart';
import '../../domain/localization/app_strings.dart';
import '../../platform/desktop_platform_services.dart';
import '../../services/update_checker.dart';
import '../../settings/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final strings = ref.watch(stringsProvider);

    final cards = <Widget>[
      _SettingsCard(
        title: strings.historyCard,
        icon: Icons.history,
        children: [
          _SettingsRow(
            label: strings.limitLabel,
            child: DropdownButton<int?>(
              value: settings.historyLimit,
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem(value: 50, child: Text('50')),
                const DropdownMenuItem(value: 100, child: Text('100')),
                const DropdownMenuItem(value: 500, child: Text('500')),
                const DropdownMenuItem(value: 1000, child: Text('1000')),
                DropdownMenuItem(
                    value: null, child: Text(strings.limitUnlimited)),
              ],
              onChanged: (value) => controller.apply(
                settings.copyWith(historyLimit: () => value),
              ),
            ),
          ),
          _SettingsSwitch(
            label: strings.autoCleanup,
            value: settings.autoCleanupEnabled,
            onChanged: (v) => controller.apply(
              settings.copyWith(autoCleanupEnabled: v),
            ),
          ),
          _SettingsRow(
            label: strings.retentionLabel,
            child: DropdownButton<Duration?>(
              value: settings.retentionPeriod,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(strings.retentionUnlimited)),
                DropdownMenuItem(
                    value: const Duration(days: 1),
                    child: Text(strings.retention1Day)),
                DropdownMenuItem(
                    value: const Duration(days: 7),
                    child: Text(strings.retention7Days)),
                DropdownMenuItem(
                    value: const Duration(days: 30),
                    child: Text(strings.retention30Days)),
              ],
              onChanged: (value) => controller.apply(
                settings.copyWith(retentionPeriod: () => value),
              ),
            ),
          ),
          _SettingsSwitch(
            label: strings.imagesLabel,
            subtitle: strings.imagesSubtitle,
            value: settings.imagesEnabled,
            onChanged: (v) => controller.apply(
              settings.copyWith(imagesEnabled: v),
            ),
          ),
        ],
      ),
      _SettingsCard(
        title: strings.generalCard,
        icon: Icons.tune,
        children: [
          _SettingsSwitch(
            label: strings.autostartLabel,
            value: settings.launchAtStartup,
            onChanged: (v) async {
              final startup = ref.read(startupServiceProvider);
              v ? await startup.enable() : await startup.disable();
              await controller.apply(settings.copyWith(launchAtStartup: v));
            },
          ),
          _SettingsSwitch(
            label: strings.monitoringLabel,
            value: settings.monitoringEnabled,
            onChanged: (v) => controller.apply(
              settings.copyWith(monitoringEnabled: v),
            ),
          ),
          _SettingsSwitch(
            label: strings.closeToTrayLabel,
            subtitle: strings.closeToTraySubtitle,
            value: settings.closeToTray,
            onChanged: (v) => controller.apply(
              settings.copyWith(closeToTray: v),
            ),
          ),
          _SettingsSwitch(
            label: strings.startMinimizedLabel,
            value: settings.startMinimized,
            onChanged: (v) => controller.apply(
              settings.copyWith(startMinimized: v),
            ),
          ),
          _SettingsSwitch(
            label: strings.alwaysOnTopLabel,
            value: settings.alwaysOnTop,
            onChanged: (v) => controller.apply(
              settings.copyWith(alwaysOnTop: v),
            ),
          ),
          _SettingsSwitch(
            label: strings.copyToastLabel,
            value: settings.showCopyToast,
            onChanged: (v) => controller.apply(
              settings.copyWith(showCopyToast: v),
            ),
          ),
          _SettingsRow(
            label: strings.shortcutLabel,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.keyboard, size: 16),
              label: Text(settings.globalShortcut),
              onPressed: () => _showShortcutDialog(settings),
            ),
          ),
        ],
      ),
      _SettingsCard(
        title: strings.appearanceCard,
        icon: Icons.palette_outlined,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SegmentedButton<ThemeModeSetting>(
              segments: [
                ButtonSegment(
                  value: ThemeModeSetting.light,
                  icon: const Icon(Icons.light_mode_outlined, size: 16),
                  label: Text(strings.themeLight),
                ),
                ButtonSegment(
                  value: ThemeModeSetting.dark,
                  icon: const Icon(Icons.dark_mode_outlined, size: 16),
                  label: Text(strings.themeDark),
                ),
                ButtonSegment(
                  value: ThemeModeSetting.system,
                  icon:
                      const Icon(Icons.brightness_auto_outlined, size: 16),
                  label: Text(strings.themeSystem),
                ),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => controller.apply(
                settings.copyWith(themeMode: selection.first),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.accentLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          _AccentDots(
            selected: settings.accentSeed,
            onSelected: (seed) => controller.apply(
              settings.copyWith(accentSeed: seed),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsRow(
            label: strings.languageLabel,
            child: SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(value: AppLanguage.english, label: Text('EN')),
                ButtonSegment(value: AppLanguage.polish, label: Text('PL')),
              ],
              selected: {settings.language},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => controller.apply(
                settings.copyWith(language: selection.first),
              ),
            ),
          ),
        ],
      ),
      _SettingsCard(
        title: strings.privacyCard,
        icon: Icons.shield_outlined,
        children: [
          _SettingsSwitch(
            label: strings.saveSecretsLabel,
            subtitle: strings.saveSecretsSubtitle,
            value: settings.saveSecrets,
            onChanged: (v) =>
                controller.apply(settings.copyWith(saveSecrets: v)),
          ),
          _SettingsRow(
            label: strings.excludedLabel(settings.excludedApps.length),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(strings.editButton),
              onPressed: () => _showExcludedAppsDialog(settings),
            ),
          ),
        ],
      ),
      _SettingsCard(
        title: strings.dataCard,
        icon: Icons.folder_outlined,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportSettings(settings),
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: Text(strings.exportJson),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importSettings,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(strings.importJson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final confirmed = await _confirm(
                strings.restoreDefaultsConfirm,
              );
              if (confirmed) await controller.resetToDefaults();
            },
            icon: const Icon(Icons.restore, size: 16),
            label: Text(strings.restoreDefaults),
          ),
        ],
      ),
      _SettingsCard(
        title: strings.aboutCard,
        icon: Icons.info_outline,
        children: [
          _SettingsRow(
            label: strings.versionLabel,
            child: Text(
              'v$kAppVersion',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          _SettingsRow(
            label: strings.authorLabel,
            child: TextButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse('https://github.com/allynIT')),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(strings.githubButton),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _checkForUpdates(context),
              icon: const Icon(Icons.system_update_alt, size: 16),
              label: Text(strings.checkUpdates),
            ),
          ),
        ],
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(strings.settingsTitle,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        for (var i = 0; i < cards.length; i++)
          _Stagger(
            index: i,
            count: cards.length,
            animation: _stagger,
            child: cards[i],
          ),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final strings = ref.read(stringsProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(strings.checkingUpdates),
          ],
        ),
      ),
    );

    UpdateInfo? info;
    String? error;
    try {
      info = await UpdateChecker().checkForUpdate();
    } on UpdateCheckException catch (e) {
      error = strings.updateFetchError(e.statusCode);
    } catch (e) {
      error = e.toString();
    }

    if (!context.mounted) return;
    Navigator.pop(context); // close the loading dialog

    if (error != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(strings.updateErrorTitle),
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.ok),
            ),
          ],
        ),
      );
      return;
    }

    if (info == null || !info.isNewer) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(strings.upToDateTitle),
          content: Text(strings.upToDateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.ok),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(strings.updateAvailableTitle),
        content: Text(
          strings.updateAvailableBody(info!.latestVersion, kAppVersion),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.laterButton),
          ),
          if (info.downloadUrl != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _runUpdateScript(context, info!.downloadUrl!);
              },
              child: Text(strings.updateButton),
            )
          else
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await launchUrl(Uri.parse(info!.releaseUrl));
              },
              child: Text(strings.openReleasePage),
            ),
        ],
      ),
    );
  }

  Future<void> _runUpdateScript(
      BuildContext context, String downloadUrl) async {
    final strings = ref.read(stringsProvider);
    // The update.ps1 script sits next to the .exe in the portable package.
    // We run it with the URL parameter and let it close the current process,
    // download the new version, swap the files and relaunch the app.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final scriptPath = '$exeDir\\update.ps1';

    if (!await File(scriptPath).exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.missingUpdateScript(scriptPath)),
          ),
        );
      }
      return;
    }

    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath,
        '-DownloadUrl', downloadUrl,
        '-AppDir', exeDir,
      ],
      mode: ProcessStartMode.detached,
    );

    // The script closes this app instance itself before swapping files.
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  static bool _isModifierKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;

  /// Builds a shortcut text from the physical keyboard state. Returns null
  /// when no valid combination can be built (missing modifier or a key
  /// without a single-char label).
  static String? _comboFromHardware(LogicalKeyboardKey? mainKey) {
    final hw = HardwareKeyboard.instance;
    final parts = <String>[];
    if (hw.isControlPressed) parts.add('Ctrl');
    if (hw.isShiftPressed) parts.add('Shift');
    if (hw.isAltPressed) parts.add('Alt');
    if (hw.isMetaPressed) parts.add('Win');
    if (mainKey != null) {
      if (mainKey.keyLabel.length != 1) return null;
      parts.add(mainKey.keyLabel.toUpperCase());
    }
    if (mainKey != null && parts.length < 2) return null;
    return parts.join('+');
  }

  Future<void> _showShortcutDialog(AppSettings settings) async {
    final strings = ref.read(stringsProvider);
    String? combo; // accepted combination (null = none yet)
    String display = settings.globalShortcut;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(strings.shortcutDialogTitle),
          content: SizedBox(
            width: 320,
            child: KeyboardListener(
              focusNode: FocusNode()..requestFocus(),
              autofocus: true,
              onKeyEvent: (event) {
                // Modifiers are tracked from the keyboard state, not from
                // key labels - labels like "Control Left" used to produce
                // invalid shortcuts such as "Control Left+X".
                if (event is! KeyDownEvent) return;
                final key = event.logicalKey;
                if (_isModifierKey(key)) {
                  setState(() => display = '${_comboFromHardware(null)}…');
                } else {
                  final built = _comboFromHardware(key);
                  setState(() {
                    if (built != null) {
                      combo = built;
                      display = built;
                    } else {
                      display = strings.shortcutHoldHint;
                    }
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  display.isEmpty ? strings.shortcutPressHint : display,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed:
                  combo == null ? null : () => Navigator.pop(context, combo),
              child: Text(strings.saveButton),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final controller = ref.read(settingsProvider.notifier);
      await controller.apply(settings.copyWith(globalShortcut: result));

      // Register immediately with the REAL callback - it used to be empty
      // here, which muted the shortcut until the app restarted.
      final shortcutService = ref.read(globalShortcutServiceProvider);
      await shortcutService.register(
          result, HotkeyShortcutService.toggleMainWindow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.shortcutChanged(result))),
        );
      }
    }
  }

  Future<void> _showExcludedAppsDialog(AppSettings settings) async {
    final strings = ref.read(stringsProvider);
    final excluded = List<String>.from(settings.excludedApps);
    final input = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(strings.excludedDialogTitle),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        decoration: InputDecoration(
                          hintText: strings.excludedHint,
                        ),
                        onSubmitted: (_) =>
                            _addExcluded(input, excluded, setState),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: strings.addTooltip,
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () =>
                          _addExcluded(input, excluded, setState),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: excluded.isEmpty
                      ? Text(strings.noExclusions)
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: excluded.length,
                          itemBuilder: (context, i) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(excluded[i]),
                            trailing: IconButton(
                              tooltip: strings.deleteTooltip,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  setState(() => excluded.removeAt(i)),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(settingsProvider.notifier).apply(
                      settings.copyWith(excludedApps: excluded),
                    );
              },
              child: Text(strings.saveButton),
            ),
          ],
        ),
      ),
    );
    input.dispose();
  }

  void _addExcluded(
    TextEditingController input,
    List<String> excluded,
    StateSetter setState,
  ) {
    final value = input.text.trim();
    if (value.isEmpty || excluded.contains(value)) return;
    setState(() {
      excluded.add(value);
      input.clear();
    });
  }

  Future<void> _exportSettings(AppSettings settings) async {
    final strings = ref.read(stringsProvider);
    final proceed = await _confirm(strings.exportWarning);
    if (!proceed) return;

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}\\settings_export.json';
    await ref.read(settingsRepositoryProvider).exportTo(path, settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.exportedTo(path))),
      );
    }
  }

  Future<void> _importSettings() async {
    final strings = ref.read(stringsProvider);
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}\\settings_export.json';

    if (!await File(path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.importMissing(path))),
        );
      }
      return;
    }

    try {
      final imported =
          await ref.read(settingsRepositoryProvider).importFrom(path);
      await ref.read(settingsProvider.notifier).apply(imported);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.importedOk)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.importError)),
        );
      }
    }
  }

  Future<bool> _confirm(String message) async {
    final strings = ref.read(stringsProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.continueButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Staggered card entrance: each card fades + slides in with a delay
/// based on its position. Runs once per settings visit.
class _Stagger extends StatelessWidget {
  final int index;
  final int count;
  final Animation<double> animation;
  final Widget child;

  const _Stagger({
    required this.index,
    required this.count,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = CurvedAnimation(
          parent: animation,
          curve: Interval(
            index / count,
            1.0,
            curve: Curves.easeOutCubic,
          ),
        );
        return FadeTransition(
          opacity: t,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(t),
            child: child,
          ),
        );
      },
    );
  }
}

class _AccentDots extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _AccentDots({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final seed in AppTheme.accentSeeds)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(seed),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(seed),
                shape: BoxShape.circle,
                border: Border.all(
                  color: seed == selected
                      ? scheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: seed == selected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium)),
          child,
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
