import '../entities/clip_item.dart';

/// Monitoruje systemowy schowek i emituje nową zawartość tekstową.
abstract class ClipboardMonitor {
  Stream<String> get onNewClipboardText;
  void start();
  void pause();
  void resume();
  bool get isRunning;

  /// Wywoływane przed wewnętrznym ustawieniem schowka przez aplikację,
  /// żeby monitor nie złapał własnego zapisu (zapobiega pętli).
  void suppressNextChange();
}

/// Trwałe przechowywanie historii (SQLite).
abstract class HistoryRepository {
  Future<List<ClipItem>> getAll({String? searchQuery, ClipContentType? filterType});
  Future<void> add(ClipItem item);
  Future<void> update(ClipItem item);
  Future<void> delete(String id);
  Future<void> clearAll({bool keepPinned = true});
  Future<void> enforceLimit(int? maxItems);
  Future<void> deleteOlderThan(Duration retention);
  Future<ClipItem?> findDuplicate(String content);
}

/// Wykrywanie potencjalnie wrażliwych danych (klucze, hasła, tokeny...).
abstract class SecretDetector {
  bool looksLikeSecret(String content);
}

/// Bezpieczne szyfrowanie/przechowywanie (system keystore + AES-GCM/ChaCha20).
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
}
