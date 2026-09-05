import 'dart:typed_data';

import '../entities/clip_item.dart';
import '../localization/app_strings.dart';

/// Monitors the system clipboard and emits new content: text,
/// images (PNG) and lists of copied files.
abstract class ClipboardMonitor {
  Stream<String> get onNewClipboardText;
  Stream<Uint8List> get onNewClipboardImage;
  Stream<List<String>> get onNewClipboardFiles;
  void start();
  void pause();
  void resume();
  bool get isRunning;

  /// Called before the app writes to the clipboard itself, so the monitor
  /// does not pick up its own write (prevents loops).
  void suppressNextChange();

  /// Same for our own image / file writes.
  void suppressNextImage();
  void suppressNextFiles();
}

/// Persistent history storage (SQLite + PNG files for images).
abstract class HistoryRepository {
  Future<List<ClipItem>> getAll({String? searchQuery, ClipContentType? filterType});
  Future<void> add(ClipItem item);
  Future<void> update(ClipItem item);
  Future<void> delete(String id);
  Future<void> clearAll({bool keepPinned = true});
  Future<void> enforceLimit(int? maxItems);
  Future<void> deleteOlderThan(Duration retention);
  Future<ClipItem?> findDuplicate(String content);

  /// Saves image bytes to a file and returns its path (for the content field).
  Future<String> saveImage(String id, Uint8List bytes);

  /// Szuka wpisu z identycznym obrazkiem (porownanie bajtow).
  Future<ClipItem?> findDuplicateImage(Uint8List bytes);
}

/// Detects potentially sensitive data (keys, passwords, tokens...).
abstract class SecretDetector {
  bool looksLikeSecret(String content);
}

/// Secure encryption/storage (system keystore + AES-GCM/ChaCha20).
abstract class SecureStorage {
  Future<void> init();
  Future<String> encrypt(String plaintext);
  Future<String> decrypt(String ciphertext);
  bool get isEncryptionAvailable;
}

abstract class GlobalShortcutService {
  Future<void> register(String accelerator, void Function() callback);
  Future<void> unregister();
}

abstract class StartupService {
  Future<void> enable();
  Future<void> disable();
  Future<bool> isEnabled();
}

abstract class TrayService {
  Future<void> init({
    required void Function() onOpenHistory,
    required void Function() onToggleMonitoring,
    required void Function() onClearHistory,
    required void Function() onOpenSettings,
    required void Function() onExit,
  });
  Future<void> updateMonitoringLabel(bool isRunning);

  /// Rebuilds the tray menu in a new language, keeping the current state.
  Future<void> updateStrings(AppStrings strings);

  /// Removes the tray icon. Called on shutdown so no icon
  /// ghost stays in the tray after the process.
  Future<void> shutdown();
}
