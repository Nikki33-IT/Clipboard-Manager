import 'dart:typed_data';

import '../entities/clip_item.dart';

/// Monitoruje systemowy schowek i emituje nowa zawartosc: tekstowa,
/// obrazkowa (PNG) oraz listy kopiowanych plikow.
abstract class ClipboardMonitor {
  Stream<String> get onNewClipboardText;
  Stream<Uint8List> get onNewClipboardImage;
  Stream<List<String>> get onNewClipboardFiles;
  void start();
  void pause();
  void resume();
  bool get isRunning;

  /// Wywoływane przed wewnętrznym ustawieniem schowka przez aplikację,
  /// żeby monitor nie złapał własnego zapisu (zapobiega pętli).
  void suppressNextChange();

  /// Jw. dla wlasnego zapisu obrazka / plikow.
  void suppressNextImage();
  void suppressNextFiles();
}

/// Trwałe przechowywanie historii (SQLite + pliki PNG obrazkow).
abstract class HistoryRepository {
  Future<List<ClipItem>> getAll({String? searchQuery, ClipContentType? filterType});
  Future<void> add(ClipItem item);
  Future<void> update(ClipItem item);
  Future<void> delete(String id);
  Future<void> clearAll({bool keepPinned = true});
  Future<void> enforceLimit(int? maxItems);
  Future<void> deleteOlderThan(Duration retention);
  Future<ClipItem?> findDuplicate(String content);

  /// Zapisuje bajty obrazka do pliku i zwraca jego sciezke (do pola content).
  Future<String> saveImage(String id, Uint8List bytes);

  /// Szuka wpisu z identycznym obrazkiem (porownanie bajtow).
  Future<ClipItem?> findDuplicateImage(Uint8List bytes);
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

  /// Usuwa ikone z traya. Wywolywane przy zamykaniu aplikacji, zeby
  /// po procesie nie zostal "duch" ikony w zasobniku.
  Future<void> shutdown();
}
