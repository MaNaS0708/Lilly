class TriggerCapabilities {
  const TriggerCapabilities({
    required this.platformSupported,
    required this.backgroundServiceSupported,
    required this.wakeWordReady,
    required this.notificationPermissionRecommended,
    required this.microphonePermissionRecommended,
    required this.isRunning,
    required this.notes,
  });

  final bool platformSupported;
  final bool backgroundServiceSupported;
  final bool wakeWordReady;
  final bool notificationPermissionRecommended;
  final bool microphonePermissionRecommended;
  final bool isRunning;
  final String notes;

  factory TriggerCapabilities.fromMap(Map<dynamic, dynamic>? map) {
    return TriggerCapabilities(
      platformSupported: map?['platformSupported'] == true,
      backgroundServiceSupported: map?['backgroundServiceSupported'] == true,
      wakeWordReady: map?['wakeWordReady'] == true,
      notificationPermissionRecommended:
          map?['notificationPermissionRecommended'] == true,
      microphonePermissionRecommended:
          map?['microphonePermissionRecommended'] == true,
      isRunning: map?['isRunning'] == true,
      notes: (map?['notes'] as String?) ?? '',
    );
  }
}
