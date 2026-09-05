import 'dart:async';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../domain/repositories/interfaces.dart';
import '../services/app_log.dart';

/// Flutter has no native "clipboard changed" event on desktop, so a light
/// poll every ~500ms is the most reliable (and simple) approach.
/// Watches text, images (PNG, e.g. PrintScreen) and copied files.
///
/// At most one event per tick: changed text has priority, images/files
/// arrive on the next tick (~500 ms later). Hashing prevents duplicates
/// and loops on our own writes.
class PollingClipboardMonitor implements ClipboardMonitor {
  /// Upper input limit for images. Clipboard BMPs can be huge (a 4K
  /// screen is ~38 MB) - and we convert to a small PNG on save anyway,
  /// so the limit is high, only against pathologies.
  static const maxImageBytes = 150 * 1024 * 1024;

  final Duration pollInterval;
  Timer? _timer;
  String? _lastSeenText;
  int? _lastSeenImageHash;
  String? _lastSeenFilesKey;
  bool _suppressText = false;
  bool _suppressImage = false;
  bool _suppressFiles = false;
  bool _imageReadFailed = false;
  bool _polling = false;
  int _tick = 0; // tick counter (drives image-poll throttling)
  bool _running = false;

  final _textController = StreamController<String>.broadcast();
  final _imageController = StreamController<Uint8List>.broadcast();
  final _filesController = StreamController<List<String>>.broadcast();

  PollingClipboardMonitor({this.pollInterval = const Duration(milliseconds: 500)});

  @override
  Stream<String> get onNewClipboardText => _textController.stream;

  @override
  Stream<Uint8List> get onNewClipboardImage => _imageController.stream;

  @override
  Stream<List<String>> get onNewClipboardFiles => _filesController.stream;

  @override
  bool get isRunning => _running;

  @override
  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  @override
  void pause() {
    _running = false;
    _timer?.cancel();
  }

  @override
  void resume() => start();

  @override
  void suppressNextChange() {
    _suppressText = true;
  }

  @override
  void suppressNextImage() {
    _suppressImage = true;
  }

  @override
  void suppressNextFiles() {
    _suppressFiles = true;
  }

  static int _hashBytes(Uint8List bytes) {
    // FNV-1a 64 - szybki, wystarczajacy do wykrywania zmian w sesji.
    var hash = 0xcbf29ce484222325;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash;
  }

  Future<void> _poll() async {
    // The previous tick has not finished yet (e.g. hanging on a locked
    // clipboard) - skip it instead of piling up requests.
    if (_polling) return;
    _polling = true;
    try {
      _tick++;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.isNotEmpty && text != _lastSeenText) {
        _lastSeenText = text;
        if (_suppressText) {
          // Aplikacja sama ustawila schowek - pomijamy, zeby uniknac petli.
          _suppressText = false;
        } else {
          _textController.add(text);
        }
        return; // text has priority - images/files arrive on the next tick
      }
      _lastSeenText = (text == null || text.isEmpty) ? null : text;

      // Reading an image is expensive (the native side shuffles it
      // through a temp file), so we check every 4th tick (~2 s).
      // Screenshots do not need a 500 ms reaction.
      if (_tick % 4 == 0) await _pollImage();
      await _pollFiles();
    } catch (_) {
      // The clipboard is occasionally unavailable (e.g. another process
      // holds it) - ignore a single failed read.
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollImage() async {
    Uint8List? bytes;
    try {
      bytes = await Pasteboard.image.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLog.write('monitor: Pasteboard.image TIMEOUT (>5s)');
          return null;
        },
      );
    } catch (e) {
      // Log only the transition into the error state, not every 500 ms.
      if (!_imageReadFailed) {
        _imageReadFailed = true;
        await AppLog.write('monitor: Pasteboard.image FAILED: $e');
      }
      return;
    }
    _imageReadFailed = false;
    if (bytes == null || bytes.isEmpty) {
      if (_lastSeenImageHash != null) {
        _lastSeenImageHash = null;
        await AppLog.write('monitor: image cleared from clipboard');
      }
      return;
    }
    if (bytes.length > maxImageBytes) return;
    final hash = _hashBytes(bytes);
    if (hash == _lastSeenImageHash) return;
    _lastSeenImageHash = hash;
    if (_suppressImage) {
      _suppressImage = false;
      return;
    }
    await AppLog.write('monitor: new image ${bytes.length} bytes');
    _imageController.add(bytes);
  }

  Future<void> _pollFiles() async {
    List<String> files;
    try {
      files = await Pasteboard.files();
    } catch (_) {
      return;
    }
    if (files.isEmpty) {
      _lastSeenFilesKey = null;
      return;
    }
    final key = files.join('\n');
    if (key == _lastSeenFilesKey) return;
    _lastSeenFilesKey = key;
    if (_suppressFiles) {
      _suppressFiles = false;
      return;
    }
    _filesController.add(List.unmodifiable(files));
  }

  void dispose() {
    _timer?.cancel();
    _textController.close();
    _imageController.close();
    _filesController.close();
  }
}
