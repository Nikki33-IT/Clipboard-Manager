import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/clip_item.dart';

/// Karta pojedynczego wpisu historii.
///
/// Celowo lekka ([StatelessWidget], zero animacji) — lista ma byc plynna
/// nawet przy kilkuset elementach. Ciezsze efekty (Tween/AnimatedContainer
/// na kazdym wierszu) zamulaly przewijanie, wiec ich tu nie ma.
class ClipTile extends StatelessWidget {
  final ClipItem item;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  /// Aktualna fraza wyszukiwania - jej wystapienia sa podswietlane w podgladzie.
  final String highlight;

  const ClipTile({
    super.key,
    required this.item,
    required this.onCopy,
    required this.onPin,
    required this.onDelete,
    this.highlight = '',
  });

  /// Ikona + etykieta typu tresci.
  (IconData, String) get _typeMeta {
    switch (item.type) {
      case ClipContentType.link:
        return (Icons.link, 'Link');
      case ClipContentType.email:
        return (Icons.alternate_email, 'E-mail');
      case ClipContentType.multilineText:
        return (Icons.notes, 'Notatka');
      case ClipContentType.image:
        return (Icons.image_outlined, 'Obraz');
      case ClipContentType.html:
        return (Icons.code, 'HTML');
      case ClipContentType.rtf:
        return (Icons.description_outlined, 'RTF');
      case ClipContentType.text:
        return (Icons.short_text, 'Tekst');
      case ClipContentType.file:
        return (Icons.folder_outlined, 'Pliki');
    }
  }

  static String _previewText(String content) =>
      content.length > 160 ? '${content.substring(0, 160)}…' : content;

  /// Nazwy plikow dla wpisu typu file (content = JSON z lista sciezek).
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

  /// Tekst zrodlowy podgladu: obrazki nie maja tekstu (jest miniaturka).
  String _previewSourceText() {
    if (item.type == ClipContentType.image) return '';
    return _previewFallback();
  }

  /// Podglad tresci z podswietlona fraza wyszukiwania (case-insensitive).
  /// Dla obrazkow nie ma tekstu - zwraca pusta tresc (w karcie widac miniaturke).
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

  /// Krotki czas wzgledny po polsku ("5 min temu", "wczoraj").
  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'przed chwilą';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours} godz. temu';
    if (diff.inDays == 1) return 'wczoraj';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (typeIcon, rawTypeLabel) = _typeMeta;
    final typeLabel = item.type == ClipContentType.file
        ? '$rawTypeLabel (${_fileNames.length})'
        : rawTypeLabel;

    final preview = _previewSpan(scheme);
    final meta = item.isSecret
        ? 'Ukryty sekret'
        : '${_relativeTime(item.copiedAt)}  •  $typeLabel'
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
                    icon: item.isSecret ? Icons.lock_outline : typeIcon,
                    isSecret: item.isSecret,
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
                              meta,
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
                  tooltip: item.isPinned ? 'Odepnij' : 'Przypnij',
                  icon: item.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  active: item.isPinned,
                  onPressed: onPin,
                ),
                _TileAction(
                  tooltip: 'Usuń',
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

/// Miniaturka obrazka ze schowka. Przy braku pliku (usuniety recznie)
/// pokazuje zastepcza ikone zamiast wywalac karty.
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
        errorBuilder: (_, __, ___) => const _TypeBadge(
          icon: Icons.broken_image_outlined,
          isSecret: false,
        ),
      ),
    );
  }
}

/// Kolorowy znaczek typu tresci po lewej stronie karty.
class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final bool isSecret;

  const _TypeBadge({required this.icon, required this.isSecret});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSecret ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isSecret
            ? scheme.onErrorContainer
            : scheme.onPrimaryContainer,
      ),
    );
  }
}

/// Kompaktowy przycisk akcji (pinezka / kosz) — mniejszy cel dotyku
/// i slabszy kolor, zeby nie konkurowal z trescia wpisu.
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
