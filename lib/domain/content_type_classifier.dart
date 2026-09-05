import '../../domain/entities/clip_item.dart';

class ContentTypeClassifier {
  static final _urlPattern = RegExp(
    r'^(https?:\/\/|www\.)[^\s]+$',
    caseSensitive: false,
  );
  static final _emailPattern = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
  );

  static ClipContentType classify(String content) {
    final trimmed = content.trim();
    if (_emailPattern.hasMatch(trimmed)) return ClipContentType.email;
    if (_urlPattern.hasMatch(trimmed)) return ClipContentType.link;
    if (trimmed.contains('\n')) return ClipContentType.multilineText;
    return ClipContentType.text;
  }
}
