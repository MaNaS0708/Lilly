import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/trigger_capabilities.dart';

class TriggerService {
  static const MethodChannel _channel = MethodChannel('lilly/trigger');

  Future<TriggerCapabilities> getCapabilities() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const TriggerCapabilities(
        platformSupported: false,
        backgroundServiceSupported: false,
        wakeWordReady: false,
        notificationPermissionRecommended: false,
        microphonePermissionRecommended: false,
        isRunning: false,
        autostartEnabled: false,
        notes: 'Trigger groundwork is currently Android-only.',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getTriggerCapabilities',
      );
      return TriggerCapabilities.fromMap(result);
    } catch (_) {
      return const TriggerCapabilities(
        platformSupported: false,
        backgroundServiceSupported: false,
        wakeWordReady: false,
        notificationPermissionRecommended: false,
        microphonePermissionRecommended: false,
        isRunning: false,
        autostartEnabled: false,
        notes: 'Could not read trigger capabilities.',
      );
    }
  }

  Future<bool> startForegroundTrigger() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'startTriggerService',
    );
    return result?['success'] == true;
  }

  Future<bool> stopForegroundTrigger() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'stopTriggerService',
    );
    return result?['success'] == true;
  }

  Future<bool> pauseForVoiceChat() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pauseTriggerForVoiceChat',
    );
    return result?['success'] == true;
  }

  Future<bool> resumeAfterVoiceChat() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'resumeTriggerAfterVoiceChat',
    );
    return result?['success'] == true;
  }

  Future<bool> isTriggerRunning() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getTriggerStatus',
    );
    return result?['isRunning'] == true;
  }

  Future<bool> setTriggerAutostart(bool enabled) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setTriggerAutostart',
      {'enabled': enabled},
    );
    return result?['success'] == true;
  }

  Future<String?> consumePendingLaunchAction() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'consumePendingLaunchAction',
    );
    return result?['action'] as String?;
  }
}
