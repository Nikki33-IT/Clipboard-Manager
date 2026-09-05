import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';import 'package:flutter_test/flutter_test.dart';

import 'package:clipvault/application/providers.dart';
import 'package:clipvault/domain/entities/clip_item.dart';
import 'package:clipvault/domain/localization/app_strings.dart';
import 'package:clipvault/domain/repositories/interfaces.dart';
import 'package:clipvault/presentation/screens/history_screen.dart';
import 'package:clipvault/presentation/screens/settings_screen.dart';
import 'package:clipvault/security/heuristic_secret_detector.dart';
import 'package:clipvault/settings/app_settings.dart';
import 'package:clipvault/settings/settings_repository.dart';

class _FakeSettingsRepository extends SettingsRepository {
  AppSettings stored;
  _FakeSettingsRepository([AppSettings? initial])
      : stored = initial ?? AppSettings.defaults();

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
  }

  @override
  Future<void> resetToDefaults() async {
    stored = AppSettings.defaults();
  }
}

class _FakeHistoryRepository implements HistoryRepository {
  final items = <ClipItem>[];

  @override
  Future<List<ClipItem>> getAll(
      {String? searchQuery, ClipContentType? filterType}) async {
    Iterable<ClipItem> out = List.of(items);
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      out = out.where((e) => e.content.contains(searchQuery));
    }
    if (filterType != null) {
      out = out.where((e) => e.type == filterType);
    }
    final sorted = out.toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.copiedAt.compareTo(a.copiedAt);
      });
    return sorted;
  }

  @override
  Future<void> add(ClipItem item) async {
    items.add(item);
  }

  @override
  Future<void> update(ClipItem item) async {
    final i = items.indexWhere((e) => e.id == item.id);
    if (i >= 0) items[i] = item;
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> clearAll({bool keepPinned = true}) async {
    items.removeWhere((e) => !keepPinned || !e.isPinned);
  }

  @override
  Future<void> enforceLimit(int? maxItems) async {}

  @override
  Future<void> deleteOlderThan(Duration retention) async {}

  @override
  Future<ClipItem?> findDuplicate(String content) async {
    for (final item in items) {
      if (item.content == content) return item;
    }
    return null;
  }

  @override
  Future<String> saveImage(String id, Uint8List bytes) async =>
      'img-$id.png';

  @override
  Future<ClipItem?> findDuplicateImage(Uint8List bytes) async => null;
}

class _FakeClipboardMonitor implements ClipboardMonitor {
  @override
  Stream<String> get onNewClipboardText => const Stream.empty();
  @override
  Stream<Uint8List> get onNewClipboardImage => const Stream.empty();
  @override
  Stream<List<String>> get onNewClipboardFiles => const Stream.empty();
  @override
  void start() {}
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  bool get isRunning => false;
  @override
  void suppressNextChange() {}
  @override
  void suppressNextImage() {}
  @override
  void suppressNextFiles() {}
}

ClipItem _item(String id, String content,
    {bool pinned = false, DateTime? at}) {
  return ClipItem(
    id: id,
    content: content,
    type: ClipContentType.text,
    copiedAt: at ?? DateTime.now(),
    isPinned: pinned,
  );
}

void main() {
  group('SettingsScreen', () {
    testWidgets('shows all sections and the author footer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider
                .overrideWithValue(_FakeSettingsRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Appearance'),
        600,
      );
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('github.com/allynIT'),
        600,
      );
      await tester.pumpAndSettle();

      expect(find.text('Accent color', skipOffstage: false),
          findsOneWidget);
      expect(find.text('Language', skipOffstage: false), findsOneWidget);
      expect(find.text('Author', skipOffstage: false), findsOneWidget);
      expect(find.text('github.com/allynIT', skipOffstage: false),
          findsOneWidget);
      expect(find.text('Check for updates', skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('language switch repaints everything in Polish',
        (tester) async {
      final repo = _FakeSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('PL'),
        600,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PL'));
      await tester.pumpAndSettle();

      expect(find.text('Wygląd'), findsOneWidget);
      expect(find.text('Autor'), findsOneWidget);
      expect(find.text('Sprawdź aktualizacje'), findsOneWidget);
    });
  });

  group('HistoryScreen', () {
    ProviderScope historyScope(List<ClipItem> seed, AppSettings settings) {
      final repo = _FakeHistoryRepository()..items.addAll(seed);
      return ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(settings)),
          historyRepositoryProvider.overrideWithValue(repo),
          clipboardMonitorProvider.overrideWithValue(_FakeClipboardMonitor()),
          secretDetectorProvider
              .overrideWithValue(HeuristicSecretDetector()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HistoryScreen(searchFocusNode: FocusNode()),
          ),
        ),
      );
    }

    testWidgets('groups entries under PINNED and TODAY headers',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(historyScope(
        [
          _item('1', 'plain entry'),
          _item('2', 'pinned entry', pinned: true),
          _item('3', 'yesterday entry',
              at: now.subtract(const Duration(days: 1, hours: 2))),
        ],
        AppSettings.defaults(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('pinned entry'), findsOneWidget);
      expect(find.text('History • 3'), findsOneWidget);
    });

    testWidgets('headers follow the Polish locale', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(historyScope(
        [
          _item('1', 'plain entry'),
          _item('3', 'yesterday entry',
              at: now.subtract(const Duration(days: 1, hours: 2))),
        ],
        AppSettings.defaults().copyWith(language: AppLanguage.polish),
      ));
      await tester.pumpAndSettle();

      expect(find.text('DZISIAJ'), findsOneWidget);
      expect(find.text('Historia • 2'), findsOneWidget);
      expect(find.text('Szukaj w historii…'), findsOneWidget);
    });
  });
}
