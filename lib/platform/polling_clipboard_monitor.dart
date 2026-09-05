import 'dart:async';
import 'package:flutter/services.dart';

import '../domain/repositories/interfaces.dart';

/// Flutter nie ma natywnego "clipboard changed" eventu na desktopie, więc
/// najbardziej niezawodne (i proste) podejście to lekki polling co ~500ms.
/// To wystarczająco częste dla dobrego UX i pomijalne dla CPU.
class PollingClipboardMonitor implements ClipboardMonitor {
  final Duration pollInterval;
  Timer? _timer;
  String? _lastSeen;
  bool _suppressNext = false;
  bool _running = false;

  final _controller = StreamController<String>.broadcast();

  PollingClipboardMonitor({this.pollInterval = const Duration(milliseconds: 500)});

  @override
  Stream<String> get onNewClipboardText => _controller.stream;

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
    _suppressNext = true;
  }

  Future<void> _poll() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;
      if (text == _lastSeen) return;

      _lastSeen = text;

      if (_suppressNext) {
        // Aplikacja sama ustawiła schowek - pomijamy, żeby uniknąć pętli.
        _suppressNext = false;
        return;
      }

      _controller.add(text);
    } catch (_) {
      // Schowek bywa chwilowo niedostępny (np. inny proces go blokuje) -
      // ignorujemy pojedynczy nieudany odczyt.
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
