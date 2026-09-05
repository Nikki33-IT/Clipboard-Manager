import 'package:flutter_test/flutter_test.dart';
import 'package:copypaste_clone/security/heuristic_secret_detector.dart';

void main() {
  final detector = HeuristicSecretDetector();

  test('wykrywa token GitHub', () {
    expect(
      detector.looksLikeSecret('ghp_${'a' * 40}'),
      isTrue,
    );
  });

  test('wykrywa JWT', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123def456';
    expect(detector.looksLikeSecret(jwt), isTrue);
  });

  test('wykrywa numer karty', () {
    expect(detector.looksLikeSecret('4111 1111 1111 1111'), isTrue);
  });

  test('nie wykrywa zwykłego zdania', () {
    expect(
      detector.looksLikeSecret('To jest zwykły tekst skopiowany do schowka.'),
      isFalse,
    );
  });

  test('nie wykrywa krótkiego słowa', () {
    expect(detector.looksLikeSecret('hasło'), isFalse);
  });
}
