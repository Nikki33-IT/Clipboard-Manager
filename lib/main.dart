import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'application/providers.dart';
import 'presentation/app.dart';
import 'services/app_log.dart';

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
    await AppLog.write('app: monitoring started');

    // Tray potrafi nie wstac za pierwszym razem (np. Explorer jeszcze
    // nie gotowy) - jedna ponowna proba po 3 s zamiast cichej kapitulacji.
    var trayOk = false;
    for (var attempt = 1; attempt <= 2 && !trayOk; attempt++) {
      try {
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
        await AppLog.write('app: exit requested');
        // Kolejnosc ma znaczenie:
        // 1. zdejmij ikone z traya (bez "ducha" po procesie),
        // 2. wylacz przechwytywanie zamkniecia i poczekaj na potwierdzenie
        //    ze strony natywnej (inaczej destroy() konczy jako "schowaj"),
        // 3. zniszcz okno,
        // 4. exit(0) jako gwarancja - proces znika na pewno, nawet gdyby
        //    ktorys z powyzszych krokow natywnych zawiodl.
        try {
          await tray.shutdown();
        } catch (_) {}
        try {
          await windowManager.setPreventClose(false);
          await windowManager.destroy();
        } catch (_) {}
        exit(0);
      },
        );
        trayOk = true;
        await AppLog.write('app: tray init OK (attempt $attempt)');
      } catch (e) {
        await AppLog.write('app: tray init FAILED (attempt $attempt): $e');
        if (attempt == 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

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
