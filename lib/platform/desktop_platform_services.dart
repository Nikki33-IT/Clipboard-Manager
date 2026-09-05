import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/repositories/interfaces.dart';
import '../domain/localization/app_strings.dart';
import '../services/app_log.dart';

class TrayManagerService implements TrayService {
  void Function()? _onOpenHistory;
  void Function()? _onToggleMonitoring;
  void Function()? _onClearHistory;
  void Function()? _onOpenSettings;
  void Function()? _onExit;
  AppStrings _strings = EnStrings();
  bool _isRunning = true;

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
      // The menu still makes sense without an icon, so carry on.
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
    _isRunning = isRunning;
    await _rebuildMenu(isRunning: isRunning);
  }

  @override
  Future<void> updateStrings(AppStrings strings) async {
    _strings = strings;
    await _rebuildMenu(isRunning: _isRunning);
  }

  @override
  Future<void> shutdown() async {
    await trayManager.destroy();
  }

  Future<void> _rebuildMenu({required bool isRunning}) async {
    final menu = Menu(items: [
      MenuItem(key: 'open_history', label: _strings.trayOpenHistory),
      MenuItem(
          key: 'toggle_monitoring',
          label: _strings.trayToggleMonitoring(isRunning)),
      MenuItem(key: 'clear_history', label: _strings.trayClearHistory),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: _strings.traySettings),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: _strings.trayQuit),
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
    // LEFT button: open the app window.
    AppLog.write('tray: left-click icon -> open window');
    onOpenHistory();
  }

  @override
  void onTrayIconRightMouseDown() {
    // RIGHT button: options menu (close etc.). The native side never pops
    // it by itself - only an explicit popUpContextMenu() shows it.
    AppLog.write('tray: right-click icon -> popup menu');
    _popupMenu();
  }

  /// Showing the menu with error handling - the call is async while the
  /// listener is synchronous, so errors must be caught here, not by callers.
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
  static const defaultAccelerator = 'Ctrl+Shift+V';
  HotKey? _registered;

  /// Shows the main window when hidden, hides it when visible.
  /// Shared by the startup registration and the settings dialog so both
  /// behave identically.
  static Future<void> toggleMainWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  /// Checks whether a shortcut text makes sense: at least 1 modifier +
  /// exactly 1 key. Guards against garbage like "Control Left+X" (once
  /// produced by the dialog) and against a lone letter as global shortcut.
  static bool isValidAccelerator(String accelerator) {
    final parts = accelerator
        .split('+')
        .map((p) => _normalizePart(p.trim().toLowerCase()))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 2) return false;
    var mods = 0;
    var keys = 0;
    for (final part in parts) {
      if (_isModifier(part)) {
        mods++;
      } else if (part.length == 1 || _functionKeys.contains(part)) {
        keys++;
      } else {
        return false;
      }
    }
    return mods >= 1 && keys == 1;
  }

  static final _functionKeys = {
    for (var i = 1; i <= 12; i++) 'f$i',
  };

  /// Wycina okreslenia strony ("left"/"right") z etykiet w stylu
  /// "Control Left" czy "Left Shift" - obie kolejnosci wystepuja na roznych
  /// ukladach klawiatur i w roznych wersjach dialogu.
  static String _normalizePart(String part) {
    var p = ' $part ';
    for (final side in [' left ', ' right ']) {
      p = p.replaceAll(side, ' ');
    }
    return p.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isModifier(String part) =>
      part == 'ctrl' ||
      part == 'control' ||
      part.startsWith('control') ||
      part == 'shift' ||
      part.startsWith('shift') ||
      part == 'alt' ||
      part.startsWith('alt') ||
      part == 'cmd' ||
      part == 'meta' ||
      part.startsWith('meta') ||
      part == 'win' ||
      part.startsWith('win');

  @override
  Future<void> register(String accelerator, void Function() callback) async {
    await unregister();
    final hotKey = parseAccelerator(accelerator);
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) => callback(),
    );
    _registered = hotKey;
    // NOTE: native RegisterHotKey reports no error when the system rejects
    // a shortcut (taken by another app) - then the event simply never
    // arrives. Hence the "fired" log in the callback as the only proof.
    await AppLog.write('hotkey: registered "$accelerator"');
  }

  @override
  Future<void> unregister() async {
    if (_registered != null) {
      await hotKeyManager.unregister(_registered!);
      _registered = null;
    }
  }

  /// Public wrapper for unit tests.
  static HotKey parseAccelerator(String accelerator) =>
      _parseAccelerator(accelerator);

  static const Map<String, PhysicalKeyboardKey> _keyMap = {
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
    '0': PhysicalKeyboardKey.digit0, '1': PhysicalKeyboardKey.digit1,
    '2': PhysicalKeyboardKey.digit2, '3': PhysicalKeyboardKey.digit3,
    '4': PhysicalKeyboardKey.digit4, '5': PhysicalKeyboardKey.digit5,
    '6': PhysicalKeyboardKey.digit6, '7': PhysicalKeyboardKey.digit7,
    '8': PhysicalKeyboardKey.digit8, '9': PhysicalKeyboardKey.digit9,
    'F1': PhysicalKeyboardKey.f1, 'F2': PhysicalKeyboardKey.f2,
    'F3': PhysicalKeyboardKey.f3, 'F4': PhysicalKeyboardKey.f4,
    'F5': PhysicalKeyboardKey.f5, 'F6': PhysicalKeyboardKey.f6,
    'F7': PhysicalKeyboardKey.f7, 'F8': PhysicalKeyboardKey.f8,
    'F9': PhysicalKeyboardKey.f9, 'F10': PhysicalKeyboardKey.f10,
    'F11': PhysicalKeyboardKey.f11, 'F12': PhysicalKeyboardKey.f12,
  };

  static HotKey _parseAccelerator(String accelerator) {
    final parts = accelerator
        .split('+')
        .map((p) => _normalizePart(p.trim().toLowerCase()))
        .toList();
    final modifiers = <HotKeyModifier>[];
    String letter = 'V';

    void addMod(HotKeyModifier m) {
      if (!modifiers.contains(m)) modifiers.add(m);
    }

    for (final part in parts) {
      if (part == 'ctrl' || part == 'control' || part.startsWith('control')) {
        addMod(HotKeyModifier.control);
      } else if (part == 'shift' || part.startsWith('shift')) {
        addMod(HotKeyModifier.shift);
      } else if (part == 'alt' || part.startsWith('alt')) {
        addMod(HotKeyModifier.alt);
      } else if (part == 'cmd' ||
          part == 'meta' ||
          part.startsWith('meta') ||
          part == 'win' ||
          part.startsWith('win')) {
        addMod(HotKeyModifier.meta);
      } else if (part.length == 1 || _functionKeys.contains(part)) {
        letter = part.toUpperCase();
      }
    }

    return HotKey(
      key: _keyMap[letter] ?? PhysicalKeyboardKey.keyV,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }
}
