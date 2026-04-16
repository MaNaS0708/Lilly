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
        notes: 'Trigger groundwork is currently Android-only.',
      );
    }

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getTriggerCapabilities',
    );
    return TriggerCapabilities.fromMap(result);
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

  Future<bool> isTriggerRunning() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getTriggerStatus',
    );
    return result?['isRunning'] == true;
  }
}
