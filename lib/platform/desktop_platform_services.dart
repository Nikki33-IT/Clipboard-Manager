import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';

import '../domain/repositories/interfaces.dart';
import '../services/app_log.dart';

class TrayManagerService implements TrayService {
  void Function()? _onOpenHistory;
  void Function()? _onToggleMonitoring;
  void Function()? _onClearHistory;
  void Function()? _onOpenSettings;
  void Function()? _onExit;

  @override
  Future<void> init({
    required void Function() onOpenHistory,
    required void Function() onToggleMonitoring,
    required void Function() onClearHistory,
    required void Function() onOpenSettings,
    required void Function() onExit,
  }) async {
    _onOpenHistory = onOpenHistory;
    _onToggleMonitoring = onToggleMonitoring;
    _onClearHistory = onClearHistory;
    _onOpenSettings = onOpenSettings;
    _onExit = onExit;

    await AppLog.write('tray: init start');
    try {
      await trayManager.setIcon('assets/tray_icon.ico');
      await AppLog.write('tray: icon OK');
    } catch (e) {
      // Bez ikony menu nadal ma sens, wiec lecimy dalej.
      await AppLog.write('tray: setIcon FAILED: $e');
    }
    try {
      await trayManager.setToolTip('ClipVault');
    } catch (e) {
      await AppLog.write('tray: setToolTip FAILED: $e');
    }
    await _rebuildMenu(isRunning: true);
    await AppLog.write('tray: menu OK');

    trayManager.addListener(_TrayListener(
      onOpenHistory: () => _onOpenHistory?.call(),
      onToggleMonitoring: () => _onToggleMonitoring?.call(),
      onClearHistory: () => _onClearHistory?.call(),
      onOpenSettings: () => _onOpenSettings?.call(),
      onExit: () => _onExit?.call(),
    ));
  }

  @override
  Future<void> updateMonitoringLabel(bool isRunning) async {
    await _rebuildMenu(isRunning: isRunning);
  }

  @override
  Future<void> shutdown() async {
    await trayManager.destroy();
  }

  Future<void> _rebuildMenu({required bool isRunning}) async {
    final menu = Menu(items: [
      MenuItem(key: 'open_history', label: 'Otwórz historię'),
      MenuItem(key: 'toggle_monitoring', label: isRunning ? 'Wstrzymaj monitorowanie' : 'Wznów monitorowanie'),
      MenuItem(key: 'clear_history', label: 'Wyczyść historię'),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: 'Ustawienia'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Zamknij aplikację'),
    ]);
    await trayManager.setContextMenu(menu);
  }
}

class _TrayListener with TrayListener {
  final void Function() onOpenHistory;
  final void Function() onToggleMonitoring;
  final void Function() onClearHistory;
  final void Function() onOpenSettings;
  final void Function() onExit;

  _TrayListener({
    required this.onOpenHistory,
    required this.onToggleMonitoring,
    required this.onClearHistory,
    required this.onOpenSettings,
    required this.onExit,
  });

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    AppLog.write('tray: click ${menuItem.key}');
    switch (menuItem.key) {
      case 'open_history':
        onOpenHistory();
        break;
      case 'toggle_monitoring':
        onToggleMonitoring();
        break;
      case 'clear_history':
        onClearHistory();
        break;
      case 'settings':
        onOpenSettings();
        break;
      case 'exit':
        onExit();
        break;
    }
  }

  @override
  void onTrayIconMouseDown() {
    // Lewy klik pokazuje menu (z "Zamknij aplikacje"), a nie tylko okno -
    // inaczej opcja zamkniecia jest dla uzytkownika nie do znalezienia.
    AppLog.write('tray: left-click icon -> popup menu');
    _popupMenu();
  }

  /// Pokazanie menu z obsluga bledow - wywolanie jest async, a listener
  /// jest synchroniczny, wiec blad trzeba zlapac tu, nie u wolajacego.
  Future<void> _popupMenu() async {
    try {
      await trayManager.popUpContextMenu();
      await AppLog.write('tray: popup menu shown');
    } catch (e) {
      await AppLog.write('tray: popup menu FAILED: $e');
    }
  }
}

class LaunchAtStartupService implements StartupService {
  LaunchAtStartupService() {
    launchAtStartup.setup(
      appName: 'ClipVault',
      appPath: Platform.resolvedExecutable,
    );
  }

  @override
  Future<void> enable() => launchAtStartup.enable();

  @override
  Future<void> disable() => launchAtStartup.disable();

  @override
  Future<bool> isEnabled() => launchAtStartup.isEnabled();
}

class HotkeyShortcutService implements GlobalShortcutService {
  HotKey? _registered;

  @override
  Future<void> register(String accelerator, void Function() callback) async {
    await unregister();
    final hotKey = _parseAccelerator(accelerator);
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) => callback(),
    );
    _registered = hotKey;
  }

  @override
  Future<void> unregister() async {
    if (_registered != null) {
      await hotKeyManager.unregister(_registered!);
      _registered = null;
    }
  }

  static const Map<String, PhysicalKeyboardKey> _letterKeys = {
    'A': PhysicalKeyboardKey.keyA, 'B': PhysicalKeyboardKey.keyB,
    'C': PhysicalKeyboardKey.keyC, 'D': PhysicalKeyboardKey.keyD,
    'E': PhysicalKeyboardKey.keyE, 'F': PhysicalKeyboardKey.keyF,
    'G': PhysicalKeyboardKey.keyG, 'H': PhysicalKeyboardKey.keyH,
    'I': PhysicalKeyboardKey.keyI, 'J': PhysicalKeyboardKey.keyJ,
    'K': PhysicalKeyboardKey.keyK, 'L': PhysicalKeyboardKey.keyL,
    'M': PhysicalKeyboardKey.keyM, 'N': PhysicalKeyboardKey.keyN,
    'O': PhysicalKeyboardKey.keyO, 'P': PhysicalKeyboardKey.keyP,
    'Q': PhysicalKeyboardKey.keyQ, 'R': PhysicalKeyboardKey.keyR,
    'S': PhysicalKeyboardKey.keyS, 'T': PhysicalKeyboardKey.keyT,
    'U': PhysicalKeyboardKey.keyU, 'V': PhysicalKeyboardKey.keyV,
    'W': PhysicalKeyboardKey.keyW, 'X': PhysicalKeyboardKey.keyX,
    'Y': PhysicalKeyboardKey.keyY, 'Z': PhysicalKeyboardKey.keyZ,
  };

  HotKey _parseAccelerator(String accelerator) {
    final parts = accelerator.split('+').map((p) => p.trim().toLowerCase()).toList();
    final modifiers = <HotKeyModifier>[];
    String letter = 'V';

    for (final part in parts) {
      switch (part) {
        case 'ctrl':
        case 'control':
          modifiers.add(HotKeyModifier.control);
          break;
        case 'shift':
          modifiers.add(HotKeyModifier.shift);
          break;
        case 'alt':
          modifiers.add(HotKeyModifier.alt);
          break;
        case 'cmd':
        case 'meta':
          modifiers.add(HotKeyModifier.meta);
          break;
        default:
          if (part.length == 1) letter = part.toUpperCase();
      }
    }

    return HotKey(
      key: _letterKeys[letter] ?? PhysicalKeyboardKey.keyV,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }
}
