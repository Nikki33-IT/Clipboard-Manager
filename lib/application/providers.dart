import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/sqlite_history_repository.dart';
import '../domain/content_type_classifier.dart';
import '../domain/entities/clip_item.dart';
import '../domain/repositories/interfaces.dart';
import '../platform/desktop_platform_services.dart';
import '../platform/polling_clipboard_monitor.dart';
import '../security/heuristic_secret_detector.dart';
import '../services/app_log.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';

const _uuid = Uuid();

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return SqliteHistoryRepository();
});

final clipboardMonitorProvider = Provider<ClipboardMonitor>((ref) {
  final monitor = PollingClipboardMonitor();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});

final secretDetectorProvider = Provider<SecretDetector>((ref) {
  return HeuristicSecretDetector();
});

final startupServiceProvider = Provider<StartupService>((ref) {
  return LaunchAtStartupService();
});

final globalShortcutServiceProvider = Provider<GlobalShortcutService>((ref) {
  return HotkeyShortcutService();
});

final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayManagerService();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});

class SettingsController extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  /// Konczy sie, gdy ustawienia zostana wczytane z dysku. Trzeba na to
  /// poczekac przed pierwszym odczytem (np. rejestracja skrotu w main),
  /// inaczej dostaje sie wartosci domyslne zamiast zapisanych przez usera.
  late final Future<void> initialized;

  SettingsController(this._repo) : super(AppSettings.defaults()) {
    initialized = _load();
  }

  Future<void> _load() async {
    state = await _repo.load();
  }

  /// Przyjmuje gotowy nowy obiekt AppSettings (np. z .copyWith(...)) i
  /// zapisuje go zarówno w stanie, jak i na dysku.
  Future<void> apply(AppSettings newSettings) async {
    state = newSettings;
    await _repo.save(state);
  }

  Future<void> resetToDefaults() async {
    await _repo.resetToDefaults();
    state = AppSettings.defaults();
  }
}

/// Kontroler historii - serce logiki aplikacji: nasłuchuje schowka,
/// deduplikuje, wykrywa sekrety, egzekwuje limity.
final historyControllerProvider =
    StateNotifierProvider<HistoryController, List<ClipItem>>((ref) {
  return HistoryController(
    historyRepository: ref.watch(historyRepositoryProvider),
    clipboardMonitor: ref.watch(clipboardMonitorProvider),
    secretDetector: ref.watch(secretDetectorProvider),
    getSettings: () => ref.read(settingsProvider),
  );
});

class HistoryController extends StateNotifier<List<ClipItem>> {
  final HistoryRepository historyRepository;
  final ClipboardMonitor clipboardMonitor;
  final SecretDetector secretDetector;
  final AppSettings Function() getSettings;

  HistoryController({
    required this.historyRepository,
    required this.clipboardMonitor,
    required this.secretDetector,
    required this.getSettings,
  }) : super([]) {
    clipboardMonitor.onNewClipboardText.listen(_handleNewClipboardText);
    clipboardMonitor.onNewClipboardImage.listen(_handleNewClipboardImage);
    clipboardMonitor.onNewClipboardFiles.listen(_handleNewClipboardFiles);
    _refresh();
  }

  Future<void> _refresh({String? query, ClipContentType? filter}) async {
    state = await historyRepository.getAll(
      searchQuery: query,
      filterType: filter,
    );
  }

  Future<void> search(String query) => _refresh(query: query);

  void startMonitoring() => clipboardMonitor.start();
  void pauseMonitoring() => clipboardMonitor.pause();
  bool get isMonitoring => clipboardMonitor.isRunning;

  Future<void> _handleNewClipboardText(String text) async {
    final settings = getSettings();
    if (!settings.monitoringEnabled) return;

    final isSecret = secretDetector.looksLikeSecret(text);
    if (isSecret && !settings.saveSecrets) {
      return; // Nie zapisujemy potencjalnych sekretów, jeśli wyłączone.
    }

    // Ogranicz rozmiar wpisu (np. 200k znaków), żeby nie rozdąć bazy.
    final limitedText = text.length > 200000 ? text.substring(0, 200000) : text;

    final duplicate = await historyRepository.findDuplicate(limitedText);
    if (duplicate != null) {
      // Przenieś na początek, zaktualizuj metadane zamiast duplikować.
      final updated = duplicate.copyWith(lastUsedAt: DateTime.now());
      await historyRepository.update(updated);
    } else {
      final item = ClipItem(
        id: _uuid.v4(),
        content: limitedText,
        type: ContentTypeClassifier.classify(limitedText),
        copiedAt: DateTime.now(),
        isSecret: isSecret,
      );
      await historyRepository.add(item);
    }

    await _enforceRetention(settings);
    await _refresh();
  }

  Future<void> _enforceRetention(AppSettings settings) async {
    await historyRepository.enforceLimit(settings.historyLimit);
    if (settings.retentionPeriod != null) {
      await historyRepository.deleteOlderThan(settings.retentionPeriod!);
    }
  }

  Future<void> _handleNewClipboardImage(Uint8List bytes) async {
    final settings = getSettings();
    await AppLog.write(
        'history: image event ${bytes.length}B (monitoring=${settings.monitoringEnabled}, images=${settings.imagesEnabled})');
    if (!settings.monitoringEnabled || !settings.imagesEnabled) return;
    if (bytes.isEmpty ||
        bytes.length > PollingClipboardMonitor.maxImageBytes) {
      return;
    }

    final duplicate = await historyRepository.findDuplicateImage(bytes);
    if (duplicate != null) {
      // Przenieś na początek, zaktualizuj metadane zamiast duplikować.
      final updated = duplicate.copyWith(lastUsedAt: DateTime.now());
      await historyRepository.update(updated);
    } else {
      final id = _uuid.v4();
      final path = await historyRepository.saveImage(id, bytes);
      final item = ClipItem(
        id: id,
        content: path,
        type: ClipContentType.image,
        copiedAt: DateTime.now(),
      );
      await historyRepository.add(item);
      await AppLog.write(
          'history: saved image ${(bytes.length / 1024).round()} KB');
    }

    await _enforceRetention(settings);
    await _refresh();
  }

  Future<void> _handleNewClipboardFiles(List<String> paths) async {
    final settings = getSettings();
    if (!settings.monitoringEnabled || !settings.imagesEnabled) return;
    if (paths.isEmpty) return;

    final content = jsonEncode(paths);
    if (content.length > 200000) return;

    final duplicate = await historyRepository.findDuplicate(content);
    if (duplicate != null) {
      final updated = duplicate.copyWith(lastUsedAt: DateTime.now());
      await historyRepository.update(updated);
    } else {
      final item = ClipItem(
        id: _uuid.v4(),
        content: content,
        type: ClipContentType.file,
        copiedAt: DateTime.now(),
      );
      await historyRepository.add(item);
      await AppLog.write('history: saved ${paths.length} file(s)');
    }

    await _enforceRetention(settings);
    await _refresh();
  }

  /// Kopiuje element z powrotem do schowka - sygnalizuje monitorowi,
  /// żeby pominął tę zmianę i nie stworzył pętli / duplikatu.
  Future<void> copyToClipboard(ClipItem item) async {
    if (item.type == ClipContentType.image) {
      await _copyImageToClipboard(item);
      return;
    }
    if (item.type == ClipContentType.file) {
      await _copyFilesToClipboard(item);
      return;
    }
    clipboardMonitor.suppressNextChange();
    await Clipboard.setData(ClipboardData(text: item.content));
    await _afterCopy(item);
  }

  Future<void> _afterCopy(ClipItem item) async {
    final updated = item.copyWith(
      lastUsedAt: DateTime.now(),
      useCount: item.useCount + 1,
    );
    await historyRepository.update(updated);
    await _refresh();
  }

  Future<void> _copyImageToClipboard(ClipItem item) async {
    try {
      final file = File(item.content);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      clipboardMonitor.suppressNextImage();
      await Pasteboard.writeImage(bytes);
      await _afterCopy(item);
    } catch (_) {
      // Np. usuniety recznie plik - po prostu nic nie robimy.
    }
  }

  Future<void> _copyFilesToClipboard(ClipItem item) async {
    try {
      final paths = (jsonDecode(item.content) as List)
          .cast<String>()
          .where((p) => File(p).existsSync())
          .toList();
      if (paths.isEmpty) return;
      clipboardMonitor.suppressNextFiles();
      await Pasteboard.writeFiles(paths);
      await _afterCopy(item);
    } catch (_) {}
  }

  Future<void> togglePin(ClipItem item) async {
    final updated = item.copyWith(isPinned: !item.isPinned);
    await historyRepository.update(updated);
    await _refresh();
  }

  Future<void> deleteItem(String id) async {
    await historyRepository.delete(id);
    await _refresh();
  }

  Future<void> clearAll({bool keepPinned = true}) async {
    await historyRepository.clearAll(keepPinned: keepPinned);
    await _refresh();
  }
}
