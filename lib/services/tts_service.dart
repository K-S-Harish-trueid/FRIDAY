import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  void Function()? onStart;
  void Function()? onComplete;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.9);
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setCancelHandler(() => onComplete?.call());
    _initialized = true;
  }

  // TTS is a nice-to-have on top of the chat flow — a plugin hiccup here
  // (uninitialized engine, no voices installed, platform error) must never
  // block sending or receiving a message. Every call is best-effort and
  // time-boxed: a hung platform channel call must not be able to freeze
  // the whole send pipeline, since stop() runs unconditionally before
  // every send.
  static const _guardTimeout = Duration(seconds: 2);

  Future<void> speak(String text) async {
    try {
      await _init().timeout(_guardTimeout);
      final clean = _stripMarkdown(text);
      if (clean.isEmpty) return;
      await _tts.stop().timeout(_guardTimeout);
      await _tts.speak(clean).timeout(_guardTimeout);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop().timeout(_guardTimeout);
    } catch (_) {
      // best-effort — in particular, this must not block before the
      // engine has ever been initialized (stop() is called unconditionally
      // on every send, long before speak() may have run _init()).
    }
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (_) {
      // best-effort
    }
  }

  /// Strips bullet chars and collapses newlines so TTS reads naturally.
  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'[•\*#`]'), '')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}