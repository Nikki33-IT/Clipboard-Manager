import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../application/providers.dart';
import '../domain/localization/app_strings.dart';
import '../settings/app_settings.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

class ClipVaultApp extends ConsumerStatefulWidget {
  const ClipVaultApp({super.key});

  @override
  ConsumerState<ClipVaultApp> createState() => _ClipVaultAppState();
}

class _ClipVaultAppState extends ConsumerState<ClipVaultApp> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // "Always on top" applies live, without restarting the app.
    ref.listen<AppSettings>(settingsProvider, (_, next) {
      windowManager.setAlwaysOnTop(next.alwaysOnTop);
    });
    // Tray menu follows the UI language.
    ref.listen<AppStrings>(stringsProvider, (_, next) {
      unawaited(ref.read(trayServiceProvider).updateStrings(next));
    });

    final themeMode = switch (settings.themeMode) {
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.system => ThemeMode.system,
    };
    final seed = Color(settings.accentSeed);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClipVault',
      theme: AppTheme.light(seed: seed),
      darkTheme: AppTheme.dark(seed: seed),
      themeMode: themeMode,
      home: const _Shell(),
    );
  }
}

/// App shell: global shortcuts, gradient backdrop, top bar and the
/// animated history/settings switch.
class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  final _searchFocusNode = FocusNode();
  bool _showSettings = false;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Back to the history screen with the cursor in search.
  void _focusSearch() {
    setState(() => _showSettings = false);
    // Wait for the rebuild onto HistoryScreen, then grab focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Shortcuts(
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
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.30),
                  scheme.surface,
                ],
                stops: const [0.0, 0.55],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    showingSettings: _showSettings,
                    onToggleSettings: () =>
                        setState(() => _showSettings = !_showSettings),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _showSettings
                          ? const SettingsScreen(key: ValueKey('settings'))
                          : HistoryScreen(
                              key: const ValueKey('history'),
                              searchFocusNode: _searchFocusNode,
                            ),
                    ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final strings = ref.watch(stringsProvider);
    // Only watch the list length, so the bar does not rebuild on every
    // change of entry contents.
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
                  strings.appName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  count == 0
                      ? strings.historyEmptyLabel
                      : strings.itemsLabel(count),
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: showingSettings
                ? strings.closeSettingsTooltip
                : strings.settingsTooltip,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(
                showingSettings
                    ? Icons.close_rounded
                    : Icons.settings_outlined,
                key: ValueKey(showingSettings),
              ),
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
