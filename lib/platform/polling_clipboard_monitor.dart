import 'dart:async';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../domain/repositories/interfaces.dart';
import '../services/app_log.dart';

/// Flutter nie ma natywnego "clipboard changed" eventu na desktopie, więc
/// najbardziej niezawodne (i proste) podejście to lekki polling co ~500ms.
/// Pilnuje tekstu, obrazkow (PNG, np. PrintScreen) oraz kopiowanych plikow.
///
/// W jednym ticku idzie maksymalnie jedno zdarzenie: zmieniony tekst ma
/// priorytet, obrazki/pliki dochodza w kolejnym ticku (500 ms pozniej).
/// Dzieki hashowaniu nie ma duplikatow ani petli przy wlasnych zapisach.
class PollingClipboardMonitor implements ClipboardMonitor {
  /// Gorny limit wejsciowy obrazka. BMP ze schowka bywa wielkie (ekran 4K
  /// to ~38 MB) - i tak konwertujemy do malego PNG przy zapisie, wiec limit
  /// jest wysoko, tylko przeciwko patologiom.
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
  int _tick = 0; // licznik diagnostyczny (loguje pierwsze ticki)
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
    // Poprzedni tick jeszcze sie nie skonczyl (np. wisi na zablokowanym
    // schowku) - pomijamy, zeby nie spietrzac zapytan.
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
        return; // tekst ma priorytet - obrazki/pliki dojda w kolejnym ticku
      }
      _lastSeenText = (text == null || text.isEmpty) ? null : text;

      // Odczyt obrazka jest drogi (natywna strona przeklada go przez plik
      // tymczasowy), wiec sprawdzamy co 4. tick (~2 s). Zrzutom to wystarcza.
      if (_tick % 4 == 0) await _pollImage();
      await _pollFiles();
    } catch (_) {
      // Schowek bywa chwilowo niedostępny (np. inny proces go blokuje) -
      // ignorujemy pojedynczy nieudany odczyt.
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
      // Loguj tylko przejscie w stan bledu, zeby nie spamowac co 500 ms.
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
