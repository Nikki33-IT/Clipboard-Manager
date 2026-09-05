import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_version.dart';
import '../../application/providers.dart';
import '../../services/update_checker.dart';
import '../../settings/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ustawienia', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),

        _SettingsCard(
          title: 'Historia',
          icon: Icons.history,
          children: [
            _SettingsRow(
              label: 'Limit elementów',
              child: DropdownButton<int?>(
                value: settings.historyLimit,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 500, child: Text('500')),
                  DropdownMenuItem(value: 1000, child: Text('1000')),
                  DropdownMenuItem(value: null, child: Text('Bez limitu')),
                ],
                onChanged: (value) => controller.apply(
                  settings.copyWith(historyLimit: () => value),
                ),
              ),
            ),
            _SettingsSwitch(
              label: 'Automatyczne czyszczenie starych elementów',
              value: settings.autoCleanupEnabled,
              onChanged: (v) => controller.apply(
                settings.copyWith(autoCleanupEnabled: v),
              ),
            ),
            _SettingsRow(
              label: 'Przechowuj wpisy',
              child: DropdownButton<Duration?>(
                value: settings.retentionPeriod,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('Bez limitu czasu')),
                  DropdownMenuItem(
                      value: Duration(days: 1), child: Text('1 dzień')),
                  DropdownMenuItem(
                      value: Duration(days: 7), child: Text('7 dni')),
                  DropdownMenuItem(
                      value: Duration(days: 30), child: Text('30 dni')),
                ],
                onChanged: (value) => controller.apply(
                  settings.copyWith(retentionPeriod: () => value),
                ),
              ),
            ),
          ],
        ),

        _SettingsCard(
          title: 'Ogólne',
          icon: Icons.tune,
          children: [
            _SettingsSwitch(
              label: 'Uruchamiaj przy starcie systemu',
              value: settings.launchAtStartup,
              onChanged: (v) async {
                final startup = ref.read(startupServiceProvider);
                v ? await startup.enable() : await startup.disable();
                await controller.apply(settings.copyWith(launchAtStartup: v));
              },
            ),
            _SettingsSwitch(
              label: 'Monitorowanie schowka aktywne',
              value: settings.monitoringEnabled,
              onChanged: (v) => controller.apply(
                settings.copyWith(monitoringEnabled: v),
              ),
            ),
            _SettingsSwitch(
              label: 'Przycisk X minimalizuje do traya',
              subtitle: 'Wylaczone: X zamyka aplikacje jak z traya',
              value: settings.closeToTray,
              onChanged: (v) => controller.apply(
                settings.copyWith(closeToTray: v),
              ),
            ),
            _SettingsSwitch(
              label: 'Start zminimalizowany do traya',
              value: settings.startMinimized,
              onChanged: (v) => controller.apply(
                settings.copyWith(startMinimized: v),
              ),
            ),
            _SettingsSwitch(
              label: 'Okno zawsze na wierzchu',
              value: settings.alwaysOnTop,
              onChanged: (v) => controller.apply(
                settings.copyWith(alwaysOnTop: v),
              ),
            ),
            _SettingsSwitch(
              label: 'Pokazuj potwierdzenie kopiowania',
              value: settings.showCopyToast,
              onChanged: (v) => controller.apply(
                settings.copyWith(showCopyToast: v),
              ),
            ),
            _SettingsRow(
              label: 'Globalny skrót',
              child: OutlinedButton.icon(
                icon: const Icon(Icons.keyboard, size: 16),
                label: Text(settings.globalShortcut),
                onPressed: () => _showShortcutDialog(context, ref, settings),
              ),
            ),
          ],
        ),

        _SettingsCard(
          title: 'Wygląd',
          icon: Icons.palette_outlined,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SegmentedButton<ThemeModeSetting>(
                segments: const [
                  ButtonSegment(
                    value: ThemeModeSetting.light,
                    icon: Icon(Icons.light_mode_outlined, size: 16),
                    label: Text('Jasny'),
                  ),
                  ButtonSegment(
                    value: ThemeModeSetting.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 16),
                    label: Text('Ciemny'),
                  ),
                  ButtonSegment(
                    value: ThemeModeSetting.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 16),
                    label: Text('Systemowy'),
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
            _AccentDots(
              selected: settings.accentSeed,
              onSelected: (seed) => controller.apply(
                settings.copyWith(accentSeed: seed),
              ),
            ),
          ],
        ),

        _SettingsCard(
          title: 'Prywatność i bezpieczeństwo',
          icon: Icons.shield_outlined,
          children: [
            _SettingsSwitch(
              label: 'Zapisuj potencjalne sekrety',
              subtitle: 'Domyślnie wykryte hasła/tokeny nie są zapisywane',
              value: settings.saveSecrets,
              onChanged: (v) => controller.apply(settings.copyWith(saveSecrets: v)),
            ),
            _SettingsRow(
              label: 'Wykluczone aplikacje (${settings.excludedApps.length})',
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edytuj'),
                onPressed: () =>
                    _showExcludedAppsDialog(context, ref, settings),
              ),
            ),
          ],
        ),

        _SettingsCard(
          title: 'Dane',
          icon: Icons.folder_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportSettings(context, ref, settings),
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: const Text('Eksportuj JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importSettings(context, ref),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Importuj JSON'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final confirmed = await _confirm(
                  context,
                  'Przywrócić domyślne ustawienia?',
                );
                if (confirmed) await controller.resetToDefaults();
              },
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Przywróć ustawienia domyślne'),
            ),
          ],
        ),
        _SettingsCard(
          title: 'O aplikacji',
          icon: Icons.info_outline,
          children: [
            _SettingsRow(
              label: 'Wersja',
              child: Text(
                'v$kAppVersion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _checkForUpdates(context),
                icon: const Icon(Icons.system_update_alt, size: 16),
                label: const Text('Sprawdź aktualizacje'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Sprawdzanie aktualizacji…'),
          ],
        ),
      ),
    );

    UpdateInfo? info;
    String? error;
    try {
      info = await UpdateChecker().checkForUpdate();
    } catch (e) {
      error = e.toString();
    }

    if (!context.mounted) return;
    Navigator.pop(context); // zamknij dialog ładowania

    if (error != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Błąd sprawdzania aktualizacji'),
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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
          title: const Text('Brak aktualizacji'),
          content: const Text('Masz już najnowszą wersję aplikacji.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dostępna aktualizacja'),
        content: Text(
          'Nowa wersja v${info!.latestVersion} jest dostępna '
          '(masz v$kAppVersion).\n\n'
          'Aplikacja pobierze paczkę portable i podmieni pliki. '
          'Zamknij aplikację po kliknięciu "Aktualizuj", jeśli poprosi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Później'),
          ),
          if (info.downloadUrl != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _runUpdateScript(context, info!.downloadUrl!);
              },
              child: const Text('Aktualizuj'),
            )
          else
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await launchUrl(Uri.parse(info!.releaseUrl));
              },
              child: const Text('Otwórz stronę wydania'),
            ),
        ],
      ),
    );
  }

  Future<void> _runUpdateScript(BuildContext context, String downloadUrl) async {
    // Skrypt update.ps1 leży obok pliku .exe w paczce portable. Uruchamiamy
    // go z parametrem URL i pozwalamy mu zamknąć bieżący proces, pobrać
    // nową wersję i podmienić pliki, po czym uruchomić aplikację ponownie.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final scriptPath = '$exeDir\\update.ps1';

    if (!await File(scriptPath).exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nie znaleziono update.ps1 obok pliku .exe ($scriptPath). '
              'Pobierz nową wersję ręcznie ze strony wydania.',
            ),
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

    // Skrypt sam zamknie tę instancję aplikacji przed podmianą plików.
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  Future<void> _showShortcutDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final captured = <String>{};
    String display = settings.globalShortcut;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Zmień globalny skrót'),
          content: SizedBox(
            width: 320,
            child: KeyboardListener(
              focusNode: FocusNode()..requestFocus(),
              autofocus: true,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  final label = event.logicalKey.keyLabel;
                  if (label.isNotEmpty) {
                    captured.add(label);
                    setState(() => display = captured.join('+'));
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  display.isEmpty ? 'Naciśnij kombinację klawiszy…' : display,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, display),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      final controller = ref.read(settingsProvider.notifier);
      await controller.apply(settings.copyWith(globalShortcut: result));

      final shortcutService = ref.read(globalShortcutServiceProvider);
      await shortcutService.register(result, () {
        // Rejestracja przekierowywana centralnie w main.dart przy starcie;
        // tutaj tylko aktualizujemy skrót na nowy accelerator.
      });
    }
  }

  Future<void> _showExcludedAppsDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final excluded = List<String>.from(settings.excludedApps);
    final input = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Wykluczone aplikacje'),
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
                        decoration: const InputDecoration(
                          hintText: 'np. keepass.exe',
                        ),
                        onSubmitted: (_) => _addExcluded(
                            input, excluded, setState),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Dodaj',
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _addExcluded(
                          input, excluded, setState),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: excluded.isEmpty
                      ? const Text('Brak wykluczen.')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: excluded.length,
                          itemBuilder: (context, i) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(excluded[i]),
                            trailing: IconButton(
                              tooltip: 'Usuń',
                              icon: const Icon(
                                  Icons.delete_outline, size: 18),
                              onPressed: () => setState(
                                  () => excluded.removeAt(i)),
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
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(settingsProvider.notifier).apply(
                      settings.copyWith(excludedApps: excluded),
                    );
              },
              child: const Text('Zapisz'),
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

  Future<void> _exportSettings(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final proceed = await _confirm(
      context,
      'Plik eksportu może zawierać poufne informacje (np. listę wykluczonych '
      'aplikacji). Kontynuować?',
    );
    if (!proceed) return;

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}\\settings_export.json';
    await ref.read(settingsRepositoryProvider).exportTo(path, settings);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wyeksportowano do: $path')),
      );
    }
  }

  Future<void> _importSettings(BuildContext context, WidgetRef ref) async {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}\\settings_export.json';

    if (!await File(path).exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie znaleziono pliku: $path')),
        );
      }
      return;
    }

    try {
      final imported = await ref.read(settingsRepositoryProvider).importFrom(path);
      await ref.read(settingsProvider.notifier).apply(imported);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ustawienia zaimportowane.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd importu: nieprawidłowy plik.')),
        );
      }
    }
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kontynuuj'),
          ),
        ],
      ),
    );
    return result ?? false;
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
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
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
