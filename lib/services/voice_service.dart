import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/voice_language.dart';
import 'settings_service.dart';

class VoiceEvent {
  const VoiceEvent({
    required this.type,
    this.text,
    this.message,
  });

  final String type;
  final String? text;
  final String? message;
}

class VoiceService {
  VoiceService({
    SettingsService? settingsService,
  }) : _settingsService = settingsService ?? SettingsService() {
    _tts.setStartHandler(() {
      _events.add(const VoiceEvent(type: 'speaking'));
    });
    _tts.setCompletionHandler(() {
      _events.add(const VoiceEvent(type: 'spoken'));
    });
    _tts.setCancelHandler(() {
      _events.add(const VoiceEvent(type: 'spoken'));
    });
  }

  final SettingsService _settingsService;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final StreamController<VoiceEvent> _events =
      StreamController<VoiceEvent>.broadcast();

  bool _speechReady = false;
  bool _listening = false;

  Stream<VoiceEvent> get events => _events.stream;

  Future<bool> initializeVoiceModel() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      _events.add(
        const VoiceEvent(
          type: 'error',
          message: 'Microphone permission is required for voice chat.',
        ),
      );
      return false;
    }

    await _prepareTts();

    if (_speechReady) {
      _events.add(const VoiceEvent(type: 'ready'));
      return true;
    }

    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && _listening) {
          _listening = false;
          _events.add(const VoiceEvent(type: 'stopped'));
        }
      },
      onError: (error) {
        _listening = false;
        _events.add(
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
      _events.add(const VoiceEvent(type: 'ready'));
      return true;
    }

    _events.add(
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

    await stopSpeaking();
    await _speech.stop();

    final localeId = await _resolveSpeechLocale();
    final started = await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;

        _events.add(
          VoiceEvent(
            type: result.finalResult ? 'final' : 'partial',
            text: text,
          ),
        );
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
      ),
    );

    if (started) {
      _listening = true;
      _events.add(const VoiceEvent(type: 'listening'));
      return true;
    }

    _events.add(
      const VoiceEvent(
        type: 'error',
        message: 'Could not start speech recognition.',
      ),
    );
    return false;
  }

  Future<bool> stopListening() async {
    _listening = false;
    await _speech.stop();
    _events.add(const VoiceEvent(type: 'stopped'));
    return true;
  }

  Future<void> speakReply(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    await stopListening();
    await _prepareTts();
    await _tts.speak(cleaned);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> _prepareTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.48);
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
    final selectedCodes = await _settingsService.getVoiceLanguageCodes();
    if (selectedCodes.isEmpty) return VoiceLanguage.english.speechLocaleId;
    return VoiceLanguage.fromCode(selectedCodes.first).speechLocaleId;
  }

  Future<String> _resolveTtsLocale() async {
    final selectedCodes = await _settingsService.getVoiceLanguageCodes();
    if (selectedCodes.isEmpty) return VoiceLanguage.english.speechLocaleId;
    return VoiceLanguage.fromCode(selectedCodes.first).speechLocaleId;
  }

  void dispose() {
    unawaited(_speech.stop());
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    unawaited(_events.close());
  }
}
