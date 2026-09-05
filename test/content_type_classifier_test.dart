import 'package:flutter_test/flutter_test.dart';
import 'package:clipvault/domain/content_type_classifier.dart';
import 'package:clipvault/domain/entities/clip_item.dart';

void main() {
  group('ContentTypeClassifier', () {
    test('detects links', () {
      expect(
        ContentTypeClassifier.classify('https://example.com'),
        ClipContentType.link,
      );
    });

    test('detects emails', () {
      expect(
        ContentTypeClassifier.classify('jane.doe@example.com'),
        ClipContentType.email,
      );
    });

    test('detects multiline text', () {
      expect(
        ContentTypeClassifier.classify('line 1\nline 2'),
        ClipContentType.multilineText,
      );
    });

    test('plain text by default', () {
      expect(
        ContentTypeClassifier.classify('just some text'),
        ClipContentType.text,
      );
    });
  });
}
