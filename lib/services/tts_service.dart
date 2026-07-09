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

  Future<void> speak(String text) async {
    await _init();
    final clean = _stripMarkdown(text);
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
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