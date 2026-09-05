import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:clipvault/platform/desktop_platform_services.dart';

void main() {
  group('isValidAccelerator', () {
    test('valid combinations', () {
      expect(HotkeyShortcutService.isValidAccelerator('Ctrl+Shift+V'), isTrue);
      expect(HotkeyShortcutService.isValidAccelerator('Alt+F4'), isTrue);
      expect(HotkeyShortcutService.isValidAccelerator('Ctrl+1'), isTrue);
    });

    test('side-qualified modifier labels are valid too', () {
      expect(
          HotkeyShortcutService.isValidAccelerator('Control Left+X'), isTrue);
      expect(
          HotkeyShortcutService.isValidAccelerator('Left Shift+V'), isTrue);
    });

    test('invalid values', () {
      expect(HotkeyShortcutService.isValidAccelerator('X'), isFalse);
      expect(HotkeyShortcutService.isValidAccelerator('Ctrl+Shift'), isFalse);
      expect(HotkeyShortcutService.isValidAccelerator(''), isFalse);
      expect(HotkeyShortcutService.isValidAccelerator('Ctrl+X+Y'), isFalse);
      expect(HotkeyShortcutService.isValidAccelerator('blah'), isFalse);
    });
  });

  group('parseAccelerator', () {
    test('Ctrl+Shift+V', () {
      final hotKey = HotkeyShortcutService.parseAccelerator('Ctrl+Shift+V');
      expect(hotKey.modifiers,
          containsAll([HotKeyModifier.control, HotKeyModifier.shift]));
      expect(hotKey.physicalKey, PhysicalKeyboardKey.keyV);
      expect(hotKey.scope, HotKeyScope.system);
    });

    test('Control Left+X gives Ctrl+X (no duplicate modifier)', () {
      final hotKey = HotkeyShortcutService.parseAccelerator('Control Left+X');
      expect(hotKey.modifiers, [HotKeyModifier.control]);
      expect(hotKey.physicalKey, PhysicalKeyboardKey.keyX);
    });
  });
}
