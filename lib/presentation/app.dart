import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import '../settings/app_settings.dart';

class CopyPasteApp extends ConsumerStatefulWidget {
  const CopyPasteApp({super.key});

  @override
  ConsumerState<CopyPasteApp> createState() => _CopyPasteAppState();
}

class _CopyPasteAppState extends ConsumerState<CopyPasteApp> {
  final _searchFocusNode = FocusNode();
  bool _showSettings = false;

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
      title: 'CopyPaste Clone',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
        },
        child: Actions(
          actions: {
            _CloseIntent: CallbackAction<_CloseIntent>(
              onInvoke: (_) {
                setState(() => _showSettings = false);
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
                    onToggleSettings: () => setState(() => _showSettings = !_showSettings),
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

  void focusSearch() {
    setState(() => _showSettings = false);
    _searchFocusNode.requestFocus();
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _TopBar extends StatelessWidget {
  final bool showingSettings;
  final VoidCallback onToggleSettings;

  const _TopBar({required this.showingSettings, required this.onToggleSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.content_paste, size: 20),
          const SizedBox(width: 8),
          const Text('CopyPaste Clone', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: Icon(showingSettings ? Icons.close : Icons.settings_outlined),
            onPressed: onToggleSettings,
          ),
        ],
      ),
    );
  }
}
