import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/clip_item.dart';
import '../../domain/localization/app_strings.dart';

/// A single history entry card.
///
/// Deliberately light - the parent list handles entrance animations, so
/// tiles themselves carry no animation controllers and scroll stays smooth.
class ClipTile extends ConsumerWidget {
  final ClipItem item;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  /// Current search phrase - its occurrences are highlighted in the preview.
  final String highlight;

  const ClipTile({
    super.key,
    required this.item,
    required this.onCopy,
    required this.onPin,
    required this.onDelete,
    this.highlight = '',
  });

  /// Icon + label + badge colors per content type.
  ({IconData icon, String label, Color bg, Color fg}) _typeMeta(
      ColorScheme scheme, AppStrings strings) {
    switch (item.type) {
      case ClipContentType.link:
        return (
          icon: Icons.link,
          label: strings.typeLink,
          bg: scheme.tertiaryContainer,
          fg: scheme.onTertiaryContainer,
        );
      case ClipContentType.email:
        return (
          icon: Icons.alternate_email,
          label: strings.typeEmail,
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
        );
      case ClipContentType.multilineText:
        return (
          icon: Icons.notes,
          label: strings.typeNote,
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
        );
      case ClipContentType.image:
        return (
          icon: Icons.image_outlined,
          label: strings.typeImage,
          bg: scheme.tertiaryContainer,
          fg: scheme.onTertiaryContainer,
        );
      case ClipContentType.html:
        return (
          icon: Icons.code,
          label: strings.typeHtml,
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
        );
      case ClipContentType.rtf:
        return (
          icon: Icons.description_outlined,
          label: strings.typeRtf,
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
        );
      case ClipContentType.file:
        return (
          icon: Icons.folder_outlined,
          label: strings.typeFiles(_fileNames.length),
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
        );
      case ClipContentType.text:
        return (
          icon: Icons.short_text,
          label: strings.typeText,
          bg: scheme.primaryContainer,
          fg: scheme.onPrimaryContainer,
        );
    }
  }

  static String _previewText(String content) =>
      content.length > 160 ? '${content.substring(0, 160)}…' : content;

  /// File names for file-type entries (content = JSON with a path list).
  List<String> get _fileNames {
    if (item.type != ClipContentType.file) return const [];
    try {
      return (jsonDecode(item.content) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  String _previewFallback() {
    if (item.type != ClipContentType.file) return _previewText(item.content);
    final joined =
        _fileNames.map((p) => p.split(RegExp(r'[\\/]')).last).join(', ');
    return joined.length > 160 ? '${joined.substring(0, 160)}…' : joined;
  }

  /// Preview source text: images have no text (the card shows a thumbnail).
  String _previewSourceText() {
    if (item.type == ClipContentType.image) return '';
    return _previewFallback();
  }

  /// Preview text with the search phrase highlighted (case-insensitive).
  InlineSpan _previewSpan(ColorScheme scheme) {
    final text =
        item.isSecret ? '••••••••••••' : _previewSourceText();
    final query = highlight.trim();
    if (query.isEmpty || item.isSecret || item.type == ClipContentType.image) {
      return TextSpan(text: text);
    }
    final lower = text.toLowerCase();
    final needle = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = lower.indexOf(needle, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + needle.length),
        style: TextStyle(
          backgroundColor: scheme.primary,
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ));
      start = i + needle.length;
      if (start >= text.length) break;
    }
    return TextSpan(children: spans);
  }

  /// Short relative time ("5 min ago", "yesterday").
  static String _relativeTime(DateTime dt, AppStrings strings) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return strings.justNow;
    if (diff.inMinutes < 60) return strings.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return strings.hoursAgo(diff.inHours);
    if (diff.inDays == 1) return strings.yesterday;
    if (diff.inDays < 7) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (d == 1) return strings.yesterday;
      return strings.dateLabel(dt.year, dt.month, dt.day);
    }
    return strings.dateLabel(dt.year, dt.month, dt.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final strings = ref.watch(stringsProvider);
    final meta = _typeMeta(scheme, strings);

    final preview = _previewSpan(scheme);
    final metaLine = item.isSecret
        ? strings.hiddenSecret
        : '${_relativeTime(item.copiedAt, strings)}  •  ${meta.label}'
            '${item.useCount > 0 ? '  •  ${item.useCount}×' : ''}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onCopy,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.type == ClipContentType.image)
                  _ImageThumb(path: item.content)
                else
                  _TypeBadge(
                    icon: item.isSecret ? Icons.lock_outline : meta.icon,
                    isSecret: item.isSecret,
                    bg: meta.bg,
                    fg: meta.fg,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.isPinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 12,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              metaLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _TileAction(
                  tooltip:
                      item.isPinned ? strings.unpinTooltip : strings.pinTooltip,
                  icon: item.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  active: item.isPinned,
                  onPressed: onPin,
                ),
                _TileAction(
                  tooltip: strings.deleteTooltip,
                  icon: Icons.delete_outline,
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

/// Thumbnail of a clipboard image. A missing file (deleted by hand) falls
/// back to a placeholder icon instead of breaking the card.
class _ImageThumb extends StatelessWidget {
  final String path;

  const _ImageThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          final scheme = Theme.of(context).colorScheme;
          return _TypeBadge(
            icon: Icons.broken_image_outlined,
            isSecret: false,
            bg: scheme.errorContainer,
            fg: scheme.onErrorContainer,
          );
        },
      ),
    );
  }
}

/// Colored content-type badge on the left side of the card.
class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final bool isSecret;
  final Color? bg;
  final Color? fg;

  const _TypeBadge({
    required this.icon,
    required this.isSecret,
    this.bg,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSecret
            ? scheme.errorContainer
            : (bg ?? scheme.primaryContainer),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isSecret
            ? scheme.onErrorContainer
            : (fg ?? scheme.onPrimaryContainer),
      ),
    );
  }
}

/// Compact action button (pin / trash) - smaller hit target and dimmer
/// color so it does not compete with the entry content.
class _TileAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _TileAction({
    required this.tooltip,
    required this.icon,
    this.active = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      splashRadius: 18,
      color: active ? scheme.primary : scheme.onSurfaceVariant,
      onPressed: onPressed,
    );
  }
}
