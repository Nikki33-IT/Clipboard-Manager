import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/clip_item.dart';
import '../widgets/clip_tile.dart';

/// Lokalny filtr listy. Dziala w pamieci na wynikach z bazy, wiec
/// przelaczanie zakladek jest natychmiastowe (bez dodatkowych zapytan SQL).
enum _HistoryFilter { all, pinned, links, emails, text }

extension _HistoryFilterLabel on _HistoryFilter {
  String get label {
    switch (this) {
      case _HistoryFilter.all:
        return 'Wszystko';
      case _HistoryFilter.pinned:
        return 'Przypięte';
      case _HistoryFilter.links:
        return 'Linki';
      case _HistoryFilter.emails:
        return 'E-maile';
      case _HistoryFilter.text:
        return 'Tekst';
    }
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  final FocusNode searchFocusNode;
  const HistoryScreen({super.key, required this.searchFocusNode});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _searchDebounce = Duration(milliseconds: 250);

  final _searchController = TextEditingController();
  Timer? _debounce;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Wyszukiwanie z debounce — zapytanie do SQLite idzie dopiero 250 ms
  /// po ostatnim klawiszu, a nie przy kazdym znaku.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {}); // odswiez przycisk czyszczenia / stan pusty
    _debounce = Timer(_searchDebounce, () {
      ref.read(historyControllerProvider.notifier).search(value);
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(historyControllerProvider.notifier).search('');
    setState(() {});
  }

  void _clearAllFilters() {
    _clearQuery();
    setState(() => _filter = _HistoryFilter.all);
  }

  List<ClipItem> _visible(List<ClipItem> items) {
    switch (_filter) {
      case _HistoryFilter.all:
        return items;
      case _HistoryFilter.pinned:
        return items.where((e) => e.isPinned).toList();
      case _HistoryFilter.links:
        return items.where((e) => e.type == ClipContentType.link).toList();
      case _HistoryFilter.emails:
        return items.where((e) => e.type == ClipContentType.email).toList();
      case _HistoryFilter.text:
        return items
            .where((e) =>
                e.type == ClipContentType.text ||
                e.type == ClipContentType.multilineText)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final visible = _visible(items);
    final hasQuery = _searchController.text.isNotEmpty;
    final isFiltering = hasQuery || _filter != _HistoryFilter.all;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: _searchController,
            focusNode: widget.searchFocusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Szukaj w historii…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Wyczyść wyszukiwanie',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearQuery,
                    )
                  : null,
            ),
            onChanged: _onQueryChanged,
            // Enter kopiuje pierwszy WIDOCZNY wynik (po filtrach),
            // niekoniecznie pierwszy w calej bazie.
            onSubmitted: (_) {
              if (visible.isNotEmpty) {
                controller.copyToClipboard(visible.first);
              }
            },
          ),
        ),
        _FilterRow(
          filter: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        _CountRow(
          total: items.length,
          shown: visible.length,
          filtering: isFiltering,
        ),
        Expanded(
          child: visible.isEmpty
              ? (isFiltering
                  ? _NoResults(onClear: _clearAllFilters)
                  : const _EmptyHistory())
              : Scrollbar(
                  child: ListView.builder(
                    key: const PageStorageKey('history-list'),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return RepaintBoundary(
                        child: ClipTile(
                          key: ValueKey(item.id),
                          item: item,
                          onCopy: () => controller.copyToClipboard(item),
                          onPin: () => controller.togglePin(item),
                          onDelete: () => controller.deleteItem(item.id),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Poziomy pasek filtrow nad lista.
class _FilterRow extends StatelessWidget {
  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onChanged;

  const _FilterRow({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _HistoryFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = _HistoryFilter.values[index];
          return ChoiceChip(
            label: Text(value.label),
            selected: filter == value,
            onSelected: (_) => onChanged(value),
          );
        },
      ),
    );
  }
}

/// Wiersz "X z Y" pod filtrami.
class _CountRow extends StatelessWidget {
  final int total;
  final int shown;
  final bool filtering;

  const _CountRow({
    required this.total,
    required this.shown,
    required this.filtering,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = filtering ? 'Wyniki: $shown z $total' : 'Historia • $total';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

/// Pusty stan: baza pusta, brak filtrow.
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.content_paste_off,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Historia jest pusta',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Skopiuj coś (Ctrl+C), żeby zobaczyć to tutaj.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Ctrl+Shift+V — pokaż okno',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pusty stan: filtry / wyszukiwanie nic nie znalazly.
class _NoResults extends StatelessWidget {
  final VoidCallback onClear;

  const _NoResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Brak wyników',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Spróbuj innej frazy albo wyczyść filtry.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Wyczyść filtry'),
            ),
          ],
        ),
      ),
    );
  }
}
