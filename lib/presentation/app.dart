import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import '../settings/app_settings.dart';

class ClipVaultApp extends ConsumerStatefulWidget {
  const ClipVaultApp({super.key});

  @override
  ConsumerState<ClipVaultApp> createState() => _ClipVaultAppState();
}

class _ClipVaultAppState extends ConsumerState<ClipVaultApp> {
  final _searchFocusNode = FocusNode();
  bool _showSettings = false;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Wraca na ekran historii i ustawia kursor w wyszukiwarce.
  void _focusSearch() {
    setState(() => _showSettings = false);
    // Poczekaj na przebudowanie na HistoryScreen, potem daj focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final themeMode = switch (settings.themeMode) {
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.system => ThemeMode.system,
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClipVault',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              const _FocusSearchIntent(),
        },
        child: Actions(
          actions: {
            _CloseIntent: CallbackAction<_CloseIntent>(
              onInvoke: (_) {
                setState(() => _showSettings = false);
                return null;
              },
            ),
            _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
              onInvoke: (_) {
                _focusSearch();
                return null;
              },
            ),
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    showingSettings: _showSettings,
                    onToggleSettings: () =>
                        setState(() => _showSettings = !_showSettings),
                  ),
                  Expanded(
                    child: _showSettings
                        ? const SettingsScreen()
                        : HistoryScreen(searchFocusNode: _searchFocusNode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _TopBar extends ConsumerWidget {
  final bool showingSettings;
  final VoidCallback onToggleSettings;

  const _TopBar({required this.showingSettings, required this.onToggleSettings});

  static String _itemsLabel(int count) {
    if (count == 1) return '1 wpis';
    final lastTwo = count % 100;
    final last = count % 10;
    if (lastTwo >= 12 && lastTwo <= 14) return '$count wpisów';
    if (last >= 2 && last <= 4) return '$count wpisy';
    return '$count wpisów';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Ogladamy tylko dlugosc listy, zeby pasek nie budowal sie
    // przy kazdej zmianie tresci wpisow.
    final count =
        ref.watch(historyControllerProvider.select((items) => items.length));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.content_paste_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ClipVault',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  count == 0 ? 'Historia schowka' : _itemsLabel(count),
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                showingSettings ? 'Zamknij ustawienia' : 'Ustawienia (Esc zamyka)',
            icon: Icon(
              showingSettings ? Icons.close_rounded : Icons.settings_outlined,
            ),
            style: showingSettings
                ? IconButton.styleFrom(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                  )
                : null,
            onPressed: onToggleSettings,
          ),
        ],
      ),
    );
  }
}
