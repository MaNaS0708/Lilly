import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/voice_language.dart';
import 'settings_service.dart';

class VoiceEvent {
  const VoiceEvent({required this.type, this.text, this.message});

  final String type;
  final String? text;
  final String? message;
}

class VoiceService {
  VoiceService({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService() {
    _tts.setStartHandler(() {
      _ttsActive = true;
      _emit(const VoiceEvent(type: 'speaking'));
    });

    _tts.setCompletionHandler(() {
      _finishTts();
    });

    _tts.setCancelHandler(() {
      _finishTts();
    });

    _tts.setErrorHandler((message) {
      debugPrint('[VoiceService] TTS engine error: $message');
      _finishTts();
    });
  }

  final SettingsService _settingsService;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final StreamController<VoiceEvent> _events =
      StreamController<VoiceEvent>.broadcast();

  bool _speechReady = false;
  bool _listening = false;
  String _lastRecognizedText = '';
  bool _finalAlreadyEmitted = false;
  List<LocaleName> _availableSpeechLocales = const [];
  int _activeSessionId = 0;
  bool _suppressRecognizerCallbacks = false;
  bool _disposed = false;
  Completer<void>? _ttsCompleter;
  bool _ttsActive = false;
  bool _ttsSpokenEventEmitted = false;

  Stream<VoiceEvent> get events => _events.stream;

  void _emit(VoiceEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }

  Future<bool> initializeVoiceModel() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      _emit(
        const VoiceEvent(
          type: 'error',
          message: 'Microphone permission is required for voice chat.',
        ),
      );
      return false;
    }

    await _prepareTts();

    if (_speechReady) {
      _emit(const VoiceEvent(type: 'ready'));
      return true;
    }

    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (_suppressRecognizerCallbacks) return;

        final normalized = status.toLowerCase();

        if (normalized.contains('listening')) {
          if (!_listening) {
            _listening = true;
            _emit(const VoiceEvent(type: 'listening'));
          }
          return;
        }

        if (normalized == 'done' || normalized == 'notlistening') {
          final wasListening = _listening;
          _listening = false;

          if (wasListening) {
            _emitBufferedFinalIfNeeded();
            _emit(const VoiceEvent(type: 'stopped'));
          }
        }
      },
      onError: (error) {
        if (_suppressRecognizerCallbacks) return;

        final message = error.errorMsg.toLowerCase();
        final isSoftStop =
            message.contains('timeout') ||
            message.contains('no match') ||
            message.contains('error_no_match') ||
            message.contains('error_speech_timeout');

        _listening = false;

        if (isSoftStop) {
          _emitBufferedFinalIfNeeded();
          _emit(const VoiceEvent(type: 'stopped'));
          return;
        }

        _emit(
          VoiceEvent(
            type: 'error',
            message: error.errorMsg.isEmpty
                ? 'Speech recognition failed.'
                : error.errorMsg,
          ),
        );
      },
    );

    if (_speechReady) {
      try {
        _availableSpeechLocales = await _speech.locales();
      } catch (_) {}
      _emit(const VoiceEvent(type: 'ready'));
      return true;
    }

    _emit(
      const VoiceEvent(
        type: 'error',
        message:
            'Speech recognition is unavailable on this device. Enable the phone speech engine first.',
      ),
    );
    return false;
  }

  Future<bool> startListening() async {
    final ready = _speechReady || await initializeVoiceModel();
    if (!ready) return false;

    _activeSessionId++;
    final sessionId = _activeSessionId;
    _suppressRecognizerCallbacks = true;
    _lastRecognizedText = '';
    _finalAlreadyEmitted = false;

    debugPrint(
      '[VoiceService] startListening: session=$sessionId, _ttsActive=$_ttsActive',
    );

    try {
      await _speech.cancel();

      final localeId = await _resolveSpeechLocale();
      _suppressRecognizerCallbacks = false;

      await _speech.listen(
        onResult: (result) {
          if (_suppressRecognizerCallbacks || sessionId != _activeSessionId) {
            return;
          }

          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;

          _lastRecognizedText = text;

          if (result.finalResult) {
            _finalAlreadyEmitted = true;
            debugPrint('[VoiceService] final transcript: "$text"');
          }

          _emit(
            VoiceEvent(
              type: result.finalResult ? 'final' : 'partial',
              text: text,
            ),
          );
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );

      _listening = true;
      debugPrint('[VoiceService] listening started');
      _emit(const VoiceEvent(type: 'listening'));
      return true;
    } catch (e) {
      _suppressRecognizerCallbacks = false;
      _listening = false;
      debugPrint('[VoiceService] startListening error: $e');
      _emit(
        VoiceEvent(
          type: 'error',
          message: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return false;
    }
  }

  Future<bool> stopListening({
    bool clearBufferedText = false,
    bool emitStopped = true,
  }) async {
    _activeSessionId++;
    _suppressRecognizerCallbacks = true;
    _listening = false;

    if (clearBufferedText) {
      _lastRecognizedText = '';
      _finalAlreadyEmitted = true;
    }

    try {
      await _speech.stop();
    } catch (_) {}

    try {
      await _speech.cancel();
    } catch (_) {}

    if (emitStopped) {
      _emit(const VoiceEvent(type: 'stopped'));
    }
    return true;
  }

  Future<void> speakReply(String text) async {
    final cleaned = _speechSafeText(text);
    if (cleaned.isEmpty) return;

    final preview = cleaned.length > 50
        ? '${cleaned.substring(0, 50)}...'
        : cleaned;
    debugPrint('[VoiceService] speakReply: starting TTS for "$preview"');

    await stopListening(clearBufferedText: true, emitStopped: false);

    try {
      await _tts.stop();
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 140));
    await _prepareTts();

    _ttsCompleter = Completer<void>();
    _ttsSpokenEventEmitted = false;
    _ttsActive = true;

    final timeoutSeconds = (cleaned.length ~/ 8).clamp(20, 70).toInt();

    try {
      final speakResult = await _tts
          .speak(cleaned)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              debugPrint('[VoiceService] TTS speak timeout');
              _finishTts();
              return null;
            },
          );

      if (speakResult == 0 || speakResult == false) {
        throw Exception('TTS engine refused to start.');
      }

      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _finishTts();
      }
    } catch (e) {
      debugPrint('[VoiceService] TTS error: $e');

      try {
        await _tts.setLanguage(VoiceLanguage.english.speechLocaleId);
        final retryResult = await _tts
            .speak(cleaned)
            .timeout(
              Duration(seconds: timeoutSeconds),
              onTimeout: () {
                debugPrint('[VoiceService] TTS retry timeout');
                _finishTts();
                return null;
              },
            );

        if (retryResult == 0 || retryResult == false) {
          throw Exception('TTS retry refused to start.');
        }

        if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
          _finishTts();
        }
      } catch (retryError) {
        debugPrint('[VoiceService] TTS retry error: $retryError');
        _finishTts();
      }
    } finally {
      _ttsCompleter = null;
      _ttsActive = false;
    }
  }

  String _speechSafeText(String text) {
    return text
        .replaceAll(RegExp(r'[`*_#>~]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _finishTts() {
    _ttsActive = false;

    final completer = _ttsCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    if (!_ttsSpokenEventEmitted) {
      _ttsSpokenEventEmitted = true;
      _emit(const VoiceEvent(type: 'spoken'));
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();

    if (_ttsActive || _ttsCompleter != null) {
      _finishTts();
    }
  }

  void _emitBufferedFinalIfNeeded() {
    final buffered = _lastRecognizedText.trim();
    if (buffered.isEmpty || _finalAlreadyEmitted) return;

    _finalAlreadyEmitted = true;
    _emit(VoiceEvent(type: 'final', text: buffered));
  }

  Future<void> _prepareTts() async {
    await _tts.awaitSpeakCompletion(true);

    try {
      await _tts.setQueueMode(0);
    } catch (_) {}

    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    final preferredLocale = await _resolveTtsLocale();
    try {
      await _tts.setLanguage(preferredLocale);
    } catch (_) {
      await _tts.setLanguage(VoiceLanguage.english.speechLocaleId);
    }
  }

  Future<String> _resolveSpeechLocale() async {
    if (_availableSpeechLocales.isEmpty) {
      try {
        _availableSpeechLocales = await _speech.locales();
      } catch (_) {}
    }

    final selectedCode = await _settingsService.getPrimaryVoiceLanguageCode();
    final selected = VoiceLanguage.fromCode(selectedCode);

    for (final candidate in _preferredSpeechLocales(selected.code)) {
      final matched = _matchSpeechLocale(candidate);
      if (matched != null) {
        return matched;
      }
    }

    for (final locale in _availableSpeechLocales) {
      final normalized = locale.localeId.toLowerCase();
      if (normalized.startsWith('${selected.code.toLowerCase()}_') ||
          normalized.startsWith('${selected.code.toLowerCase()}-')) {
        return locale.localeId;
      }
    }

    return selected.speechLocaleId;
  }

  List<String> _preferredSpeechLocales(String code) {
    switch (code) {
      case 'en':
        return const ['en_US', 'en_IN', 'en_GB'];
      case 'hi':
        return const ['hi_IN'];
      case 'es':
        return const ['es_ES', 'es_US'];
      case 'fr':
        return const ['fr_FR'];
      case 'de':
        return const ['de_DE'];
      case 'pt':
        return const ['pt_PT', 'pt_BR'];
      case 'ru':
        return const ['ru_RU'];
      default:
        return const ['en_US', 'en_IN', 'en_GB'];
    }
  }

  String? _matchSpeechLocale(String candidate) {
    for (final locale in _availableSpeechLocales) {
      if (locale.localeId.toLowerCase() == candidate.toLowerCase()) {
        return locale.localeId;
      }
    }
    return null;
  }

  Future<String> _resolveTtsLocale() async {
    final selectedCode = await _settingsService.getPrimaryVoiceLanguageCode();
    return VoiceLanguage.fromCode(selectedCode).speechLocaleId;
  }

  void dispose() {
    _disposed = true;
    unawaited(_speech.stop());
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    unawaited(_events.close());
  }
}
