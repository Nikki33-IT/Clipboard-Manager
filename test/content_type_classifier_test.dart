import 'package:flutter_test/flutter_test.dart';
import 'package:clipvault/domain/content_type_classifier.dart';
import 'package:clipvault/domain/entities/clip_item.dart';

void main() {
  group('ContentTypeClassifier', () {
    test('rozpoznaje link', () {
      expect(
        ContentTypeClassifier.classify('https://example.com'),
        ClipContentType.link,
      );
    });

    test('rozpoznaje e-mail', () {
      expect(
        ContentTypeClassifier.classify('jan.kowalski@example.com'),
        ClipContentType.email,
      );
    });

    test('rozpoznaje tekst wieloliniowy', () {
      expect(
        ContentTypeClassifier.classify('linia 1\nlinia 2'),
        ClipContentType.multilineText,
      );
    });

    test('domyślnie zwykły tekst', () {
      expect(
        ContentTypeClassifier.classify('zwykły tekst'),
        ClipContentType.text,
      );
    });
  });
}
