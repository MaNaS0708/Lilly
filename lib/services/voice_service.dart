import 'dart:async';

import 'package:flutter/services.dart';

import 'model_file_service.dart';
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

  factory VoiceEvent.fromMap(Map<dynamic, dynamic> map) {
    return VoiceEvent(
      type: (map['type'] as String?) ?? 'unknown',
      text: map['text'] as String?,
      message: map['message'] as String?,
    );
  }
}

class VoiceService {
  VoiceService({
    ModelFileService? modelFileService,
    SettingsService? settingsService,
  }) : _modelFileService = modelFileService ?? ModelFileService(),
       _settingsService = settingsService ?? SettingsService();

  static const MethodChannel _methodChannel = MethodChannel('lilly/voice');
  static const EventChannel _eventChannel = EventChannel('lilly/voice_events');

  final ModelFileService _modelFileService;
  final SettingsService _settingsService;

  Stream<VoiceEvent> get events {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return VoiceEvent.fromMap(event as Map<dynamic, dynamic>);
    });
  }

  Future<bool> initializeVoiceModel() async {
    final selectedCode = await _settingsService.getVoiceLanguageCode();
    if (selectedCode == null) {
      return false;
    }

    final modelPath = await _modelFileService.getVoskModelPath(selectedCode);

    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'initializeVoiceModel',
      {'modelPath': modelPath},
    );

    return result?['success'] == true;
  }

  Future<bool> startListening() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'startVoiceListening',
    );
    return result?['success'] == true;
  }

  Future<bool> stopListening() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'stopVoiceListening',
    );
    return result?['success'] == true;
  }
}
