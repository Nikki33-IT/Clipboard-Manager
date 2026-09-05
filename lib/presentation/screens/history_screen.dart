import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../widgets/clip_tile.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final FocusNode searchFocusNode;
  const HistoryScreen({super.key, required this.searchFocusNode});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Focus(
      onKeyEvent: (node, event) {
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              focusNode: widget.searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Szukaj w historii…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: controller.search,
              onSubmitted: (_) {
                if (items.isNotEmpty) {
                  controller.copyToClipboard(items[_selectedIndex]);
                }
              },
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? _EmptyState(scheme: scheme)
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: ListView.builder(
                      key: ValueKey(items.length),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(item.id),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 180),
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 8),
                              child: child,
                            ),
                          ),
                          child: ClipTile(
                            item: item,
                            isSelected: index == _selectedIndex,
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme scheme;
  const _EmptyState({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_paste_off, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'Historia jest pusta',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Skopiuj coś, żeby zobaczyć to tutaj.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
