import 'dart:math' as math;
import '../domain/repositories/interfaces.dart';

/// Heuristic secret detector. Not perfect by definition (impossible
/// without false positives), but covers the most common patterns.
class HeuristicSecretDetector implements SecretDetector {
  static final List<RegExp> _patterns = [
    RegExp(r'^ghp_[A-Za-z0-9]{36,}$'), // GitHub token
    RegExp(r'^sk-[A-Za-z0-9]{20,}$'), // OpenAI/Anthropic-style key
    RegExp(r'^AKIA[0-9A-Z]{16}$'), // AWS access key id
    RegExp(r'^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'), // JWT
    RegExp(r'-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    RegExp(r'^\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}$'), // payment card
  ];

  @override
  bool looksLikeSecret(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    for (final pattern in _patterns) {
      if (pattern.hasMatch(trimmed)) return true;
    }

    // Short single-word strings with high entropy and a mixed alphabet
    // (typical for randomly generated passwords/tokens).
    if (!trimmed.contains(' ') &&
        trimmed.length >= 16 &&
        trimmed.length <= 128 &&
        _hasMixedCharacterClasses(trimmed) &&
        _shannonEntropy(trimmed) > 3.5) {
      return true;
    }

    return false;
  }

  bool _hasMixedCharacterClasses(String s) {
    final hasLower = s.contains(RegExp(r'[a-z]'));
    final hasUpper = s.contains(RegExp(r'[A-Z]'));
    final hasDigit = s.contains(RegExp(r'[0-9]'));
    final classes = [hasLower, hasUpper, hasDigit].where((b) => b).length;
    return classes >= 2;
  }

  double _shannonEntropy(String s) {
    final freq = <String, int>{};
    for (final ch in s.split('')) {
      freq[ch] = (freq[ch] ?? 0) + 1;
    }
    double entropy = 0;
    for (final count in freq.values) {
      final p = count / s.length;
      entropy -= p * (p == 0 ? 0 : (_log2(p)));
    }
    return entropy;
  }

  double _log2(double x) => x <= 0 ? 0 : math.log(x) / math.log(2);
}
