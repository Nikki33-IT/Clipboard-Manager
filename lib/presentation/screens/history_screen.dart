import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/clip_item.dart';
import '../../domain/localization/app_strings.dart';
import '../widgets/clip_tile.dart';

/// Local list filter. Runs in memory on the database results, so switching
/// tabs is instant (no extra SQL queries).
enum _HistoryFilter { all, pinned, links, emails, text }

extension _HistoryFilterLabel on _HistoryFilter {
  String label(AppStrings s) {
    switch (this) {
      case _HistoryFilter.all:
        return s.filterAll;
      case _HistoryFilter.pinned:
        return s.filterPinned;
      case _HistoryFilter.links:
        return s.filterLinks;
      case _HistoryFilter.emails:
        return s.filterEmails;
      case _HistoryFilter.text:
        return s.filterText;
    }
  }
}

/// A flat list row: either a date-group header or an entry tile.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  final String label;
  const _HeaderRow(this.label);
}

class _TileRow extends _Row {
  final ClipItem item;
  const _TileRow(this.item);
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

  /// Debounced search - the SQLite query goes out 250 ms after the last
  /// keystroke, not on every character.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {}); // refresh the clear button / empty state
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

  /// Copies an entry back to the clipboard, with an optional toast.
  Future<void> _copyItem(ClipItem item) async {
    await ref.read(historyControllerProvider.notifier).copyToClipboard(item);
    if (!mounted || !context.mounted) return;
    if (ref.read(settingsProvider).showCopyToast) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ref.read(stringsProvider).copiedToast),
            duration: const Duration(seconds: 1),
          ),
        );
    }
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

  /// Groups entries: pinned section on top (unfiltered view only),
  /// then day groups (Today / Yesterday / date).
  List<_Row> _rows(List<ClipItem> visible, AppStrings s, bool plain) {
    final rows = <_Row>[];
    Iterable<ClipItem> rest = visible;
    if (plain) {
      final pinned = visible.where((e) => e.isPinned).toList();
      if (pinned.isNotEmpty) {
        rows.add(_HeaderRow(s.groupPinned));
        for (final item in pinned) {
          rows.add(_TileRow(item));
        }
        final ids = pinned.map((e) => e.id).toSet();
        rest = visible.where((e) => !ids.contains(e.id));
      }
    }
    DateTime? lastDay;
    for (final item in rest) {
      final day = DateTime(
          item.copiedAt.year, item.copiedAt.month, item.copiedAt.day);
      if (day != lastDay) {
        lastDay = day;
        rows.add(_HeaderRow(_dayLabel(day, s)));
      }
      rows.add(_TileRow(item));
    }
    return rows;
  }

  String _dayLabel(DateTime day, AppStrings s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return s.groupToday;
    if (diff == 1) return s.groupYesterday;
    return s.dateLabel(day.year, day.month, day.day);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final visible = _visible(items);
    final hasQuery = _searchController.text.isNotEmpty;
    final isFiltering = hasQuery || _filter != _HistoryFilter.all;
    final rows = _rows(visible, strings, !isFiltering);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: _searchController,
            focusNode: widget.searchFocusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: strings.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: strings.clearSearchTooltip,
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearQuery,
                    )
                  : null,
            ),
            onChanged: _onQueryChanged,
            // Enter copies the first VISIBLE result (after filters),
            // not necessarily the first one in the whole database.
            onSubmitted: (_) {
              if (visible.isNotEmpty) {
                _copyItem(visible.first);
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
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is _HeaderRow) {
                        return _GroupHeader(
                          key: ValueKey('header-${row.label}'),
                          label: row.label,
                        );
                      }
                      final item = (row as _TileRow).item;
                      return RepaintBoundary(
                        child: _Entrance(
                          id: item.id,
                          index: index,
                          child: ClipTile(
                            key: ValueKey(item.id),
                            item: item,
                            highlight: _searchController.text,
                            onCopy: () => _copyItem(item),
                            onPin: () => controller.togglePin(item),
                            onDelete: () => controller.deleteItem(item.id),
                          ),
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

/// Plays a fade+slide entrance ONCE per entry id (staggered by position).
/// Already-seen entries render statically, so scrolling stays at 60 fps
/// no matter how long the list gets.
class _Entrance extends StatefulWidget {
  final String id;
  final int index;
  final Widget child;

  static final _seen = <String>{};

  const _Entrance({
    required this.id,
    required this.index,
    required this.child,
  });

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final bool _animate;

  @override
  void initState() {
    super.initState();
    // Only the top of the list animates - the rest pops in statically.
    _animate = widget.index < 12 && _Entrance._seen.add(widget.id);
    if (_Entrance._seen.length > 3000) {
      _Entrance._seen
        ..clear()
        ..add(widget.id);
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (_animate) {
      final delay =
          Duration(milliseconds: widget.index.clamp(0, 8) * 35);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Horizontal filter bar above the list.
class _FilterRow extends ConsumerWidget {
  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onChanged;

  const _FilterRow({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
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
            label: Text(value.label(strings)),
            selected: filter == value,
            onSelected: (_) => onChanged(value),
          );
        },
      ),
    );
  }
}

/// "X of Y" row under the filters.
class _CountRow extends ConsumerWidget {
  final int total;
  final int shown;
  final bool filtering;

  const _CountRow({
    required this.total,
    required this.shown,
    required this.filtering,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = filtering
        ? strings.resultsCount(shown, total)
        : strings.historyCount(total);
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

/// Day-group header (PINNED / TODAY / date).
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

/// Empty state: database is empty, no filters.
class _EmptyHistory extends ConsumerWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final strings = ref.watch(stringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pulse(
              child: Container(
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
            ),
            const SizedBox(height: 16),
            Text(
              strings.emptyTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.emptySubtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                strings.emptyShortcutHint,
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

/// Empty state: filters / search found nothing.
class _NoResults extends ConsumerWidget {
  final VoidCallback onClear;

  const _NoResults({required this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final strings = ref.watch(stringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              strings.noResultsTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.noResultsSubtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 16),
              label: Text(strings.clearFilters),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gentle infinite pulse for the empty-state badge.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
