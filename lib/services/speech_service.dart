import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum SpeechStatus { idle, listening, processing }

class SpeechService {
  final SpeechToText _stt = SpeechToText();

  final ValueNotifier<SpeechStatus> status =
      ValueNotifier(SpeechStatus.idle);

  /// Live partial transcript — updated while listening, cleared on final result.
  final ValueNotifier<String> partialText = ValueNotifier('');

  bool _initialized = false;
  bool _continuousMode = false;
  bool _paused = false;

  /// Set after a failed [initialize] when the mic permission was denied
  /// with "don't ask again" — the permission dialog won't reappear, so the
  /// UI should point the user at app settings instead of retrying.
  bool permissionPermanentlyDenied = false;

  void Function(String text)? onResult;

  bool get isActive => _continuousMode;

  Future<bool> initialize() async {
    final micPerm = await Permission.microphone.request();
    if (!micPerm.isGranted) {
      permissionPermanentlyDenied = micPerm.isPermanentlyDenied;
      return false;
    }
    permissionPermanentlyDenied = false;

    _initialized = await _stt.initialize(
      onError: (error) {
        if (error.errorMsg != 'error_speech_timeout') {
          debugPrint('STT error: ${error.errorMsg}');
        }
        _scheduleRestart();
      },
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          _scheduleRestart();
        }
      },
    );
    return _initialized;
  }

  /// Returns false (without doing anything) if the mic permission was
  /// denied or the speech engine failed to initialize — callers must check
  /// this instead of assuming a hold always starts a real recording.
  Future<bool> startListening() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    _continuousMode = true;
    _paused = false;
    _listen();
    return true;
  }

  /// Finalizes the current listen and delivers whatever was recognized so
  /// far via [onResult] (speech_to_text's `stop()` requests a final result,
  /// unlike `cancel()` which discards). Used when the user releases the mic
  /// normally — hold to talk, release to send.
  void stopListening() {
    _continuousMode = false;
    _paused = false;
    _stt.stop();
    status.value = SpeechStatus.idle;
    partialText.value = '';
  }

  /// Discards the current listen without delivering a result. Used when the
  /// user slides away from the mic button to cancel an accidental hold.
  void cancelListening() {
    _continuousMode = false;
    _paused = false;
    _stt.cancel();
    status.value = SpeechStatus.idle;
    partialText.value = '';
  }

  void pause() {
    _paused = true;
    _stt.stop();
    partialText.value = '';
  }

  void resume() {
    if (!_continuousMode) return;
    _paused = false;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_continuousMode && !_paused) _listen();
    });
  }

  void _listen() {
    if (!_continuousMode || _paused) return;
    status.value = SpeechStatus.listening;
    _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          if (result.recognizedWords.trim().isNotEmpty) {
            partialText.value = '';
            status.value = SpeechStatus.processing;
            onResult?.call(result.recognizedWords.trim());
          }
        } else {
          // Live partial transcript
          partialText.value = result.recognizedWords;
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void _scheduleRestart() {
    if (!_continuousMode || _paused) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_continuousMode && !_paused) _listen();
    });
  }

  void dispose() {
    _stt.cancel();
    status.dispose();
    partialText.dispose();
  }
}
