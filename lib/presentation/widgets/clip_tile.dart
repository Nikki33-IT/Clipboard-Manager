import 'package:flutter/material.dart';

import '../../domain/entities/clip_item.dart';

class ClipTile extends StatelessWidget {
  final ClipItem item;
  final bool isSelected;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const ClipTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onCopy,
    required this.onPin,
    required this.onDelete,
  });

  IconData get _typeIcon {
    switch (item.type) {
      case ClipContentType.link:
        return Icons.link;
      case ClipContentType.email:
        return Icons.alternate_email;
      case ClipContentType.multilineText:
        return Icons.notes;
      case ClipContentType.image:
        return Icons.image_outlined;
      case ClipContentType.html:
        return Icons.code;
      case ClipContentType.rtf:
        return Icons.description_outlined;
      case ClipContentType.text:
        return Icons.short_text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = item.content.length > 160
        ? '${item.content.substring(0, 160)}…'
        : item.content;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onCopy,
          onDoubleTap: onCopy,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_typeIcon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.isSecret ? '••••••••••••' : preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.useCount}× użyto',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: item.isPinned ? 'Odepnij' : 'Przypnij',
                  icon: Icon(
                    item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                  ),
                  onPressed: onPin,
                ),
                IconButton(
                  tooltip: 'Usuń',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
