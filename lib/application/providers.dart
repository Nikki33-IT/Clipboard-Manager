import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/sqlite_history_repository.dart';
import '../domain/content_type_classifier.dart';
import '../domain/entities/clip_item.dart';
import '../domain/repositories/interfaces.dart';
import '../platform/desktop_platform_services.dart';
import '../platform/polling_clipboard_monitor.dart';
import '../security/heuristic_secret_detector.dart';
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
  SettingsController(this._repo) : super(AppSettings.defaults()) {
    _load();
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

    await historyRepository.enforceLimit(settings.historyLimit);
    if (settings.retentionPeriod != null) {
      await historyRepository.deleteOlderThan(settings.retentionPeriod!);
    }
    await _refresh();
  }

  /// Kopiuje element z powrotem do schowka - sygnalizuje monitorowi,
  /// żeby pominął tę zmianę i nie stworzył pętli / duplikatu.
  Future<void> copyToClipboard(ClipItem item) async {
    clipboardMonitor.suppressNextChange();
    await Clipboard.setData(ClipboardData(text: item.content));

    final updated = item.copyWith(
      lastUsedAt: DateTime.now(),
      useCount: item.useCount + 1,
    );
    await historyRepository.update(updated);
    await _refresh();
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
