import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'application/providers.dart';
import 'platform/desktop_platform_services.dart';
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

  // Closing the window minimizes to tray instead of quitting the app.
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

    // Wait for settings to load from disk - otherwise shortcut
    // registration (and minimized start) would use default values.
    await ref.read(settingsProvider.notifier).initialized;
    var settings = ref.read(settingsProvider);

    // Self-heal: if settings hold an invalid shortcut, fall back to default.
    if (!HotkeyShortcutService.isValidAccelerator(settings.globalShortcut)) {
      await AppLog.write(
          'app: invalid shortcut "${settings.globalShortcut}", fallback to default');
      settings = settings.copyWith(
          globalShortcut: HotkeyShortcutService.defaultAccelerator);
      await ref.read(settingsProvider.notifier).apply(settings);
    }

    history.startMonitoring();
    await AppLog.write('app: monitoring started');

    // The tray may fail to come up on the first try (e.g. Explorer not
    // ready yet) - one retry after 3 s instead of silently giving up.
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
        await _exitApp();
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

    await AppLog.write('app: tray init done');
    await tray.updateStrings(ref.read(stringsProvider));

    await windowManager.setAlwaysOnTop(settings.alwaysOnTop);
    if (settings.startMinimized) {
      await windowManager.hide();
      await AppLog.write('app: started minimized');
    }

    try {
      await shortcutService.register(settings.globalShortcut, () async {
        await AppLog.write('hotkey: fired, toggling window');
        await HotkeyShortcutService.toggleMainWindow();
      });
      await AppLog.write(
          'app: shortcut registered (${settings.globalShortcut})');
    } catch (e) {
      await AppLog.write('app: shortcut register FAILED: $e');
    }
  }

  /// Full shutdown: remove the tray icon, disable close interception,
  /// destroy the window, and finish with exit(0) as a guarantee.
  Future<void> _exitApp() async {
    try {
      await ref.read(trayServiceProvider).shutdown();
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  void onWindowClose() async {
    // X minimizes to tray only when that option is on - otherwise behave
    // like "Quit app" from the tray.
    if (ref.read(settingsProvider).closeToTray) {
      final isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        await windowManager.hide();
      }
    } else {
      await _exitApp();
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
