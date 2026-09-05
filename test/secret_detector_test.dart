import 'package:flutter_test/flutter_test.dart';
import 'package:clipvault/security/heuristic_secret_detector.dart';

void main() {
  final detector = HeuristicSecretDetector();

  test('detects a GitHub token', () {
    expect(
      detector.looksLikeSecret('ghp_${'a' * 40}'),
      isTrue,
    );
  });

  test('detects a JWT', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123def456';
    expect(detector.looksLikeSecret(jwt), isTrue);
  });

  test('detects a card number', () {
    expect(detector.looksLikeSecret('4111 1111 1111 1111'), isTrue);
  });

  test('ignores a regular sentence', () {
    expect(
      detector.looksLikeSecret('This is a regular sentence from the clipboard.'),
      isFalse,
    );
  });

  test('ignores a short word', () {
    expect(detector.looksLikeSecret('sunshine'), isFalse);
  });
}
