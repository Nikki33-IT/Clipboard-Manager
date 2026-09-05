import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'application/providers.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  const windowOptions = WindowOptions(
    size: Size(420, 640),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('ClipVault');
    await windowManager.show();
    await windowManager.focus();
  });

  // Zamykanie okna minimalizuje do traya zamiast zamykać aplikację.
  windowManager.setPreventClose(true);

  runApp(const ProviderScope(child: _RootApp()));
}

class _RootApp extends ConsumerStatefulWidget {
  const _RootApp();

  @override
  ConsumerState<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends ConsumerState<_RootApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _wireUpPlatformServices());
  }

  Future<void> _wireUpPlatformServices() async {
    final history = ref.read(historyControllerProvider.notifier);
    final tray = ref.read(trayServiceProvider);
    final shortcutService = ref.read(globalShortcutServiceProvider);
    final settings = ref.read(settingsProvider);

    history.startMonitoring();

    await tray.init(
      onOpenHistory: () async {
        await windowManager.show();
        await windowManager.focus();
      },
      onToggleMonitoring: () {
        if (history.isMonitoring) {
          history.pauseMonitoring();
        } else {
          history.startMonitoring();
        }
        tray.updateMonitoringLabel(history.isMonitoring);
      },
      onClearHistory: () => history.clearAll(),
      onOpenSettings: () async {
        await windowManager.show();
        await windowManager.focus();
      },
      onExit: () async {
        // Najpierw WYLACZ przechwytywanie zamkniecia (i poczekaj na
        // potwierdzenie ze strony natywnej), inaczej destroy() zostanie
        // zinterpretowane jako "schowaj do traya" i apka nie zamknie sie.
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      },
    );

    await shortcutService.register(settings.globalShortcut, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide(); // minimalizacja do traya
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ClipVaultApp();
}
