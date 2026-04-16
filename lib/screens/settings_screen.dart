import 'package:flutter/material.dart';

import '../controllers/model_controller.dart';
import '../models/model_status.dart';
import '../models/trigger_capabilities.dart';
import '../services/model_file_service.dart';
import '../services/settings_service.dart';
import '../services/trigger_service.dart';
import '../widgets/confirm_action_dialog.dart';
import 'splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings';
  final ModelController? modelController;

  const SettingsScreen({super.key, this.modelController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ModelFileService _modelFileService = ModelFileService();
  final TriggerService _triggerService = TriggerService();

  bool _saveChatsLocally = true;
  bool _enableImageInput = true;
  bool _showDebugInfo = false;
  bool _loading = true;
  bool _triggerBusy = false;

  ModelFileInfo? _modelInfo;
  TriggerCapabilities? _triggerCapabilities;

  ModelController? get _modelController => widget.modelController;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final saveChats = await _settingsService.getSaveChatsLocally();
    final enableImages = await _settingsService.getEnableImageInput();
    final showDebug = await _settingsService.getShowDebugInfo();
    final modelInfo = await _modelFileService.inspectModelFile(strict: true);
    final triggerCapabilities = await _triggerService.getCapabilities();

    if (!mounted) return;

    setState(() {
      _saveChatsLocally = saveChats;
      _enableImageInput = enableImages;
      _showDebugInfo = showDebug;
      _modelInfo = modelInfo;
      _triggerCapabilities = triggerCapabilities;
      _loading = false;
    });
  }

  Future<void> _refreshModelDetails() async {
    await _modelController?.refreshStatus();
    final modelInfo = await _modelFileService.inspectModelFile(strict: true);
    final triggerCapabilities = await _triggerService.getCapabilities();

    if (!mounted) return;

    setState(() {
      _modelInfo = modelInfo;
      _triggerCapabilities = triggerCapabilities;
    });
  }

  Future<void> _retryModelInit() async {
    if (_modelController == null) return;
    await _modelController!.initialize();
    await _refreshModelDetails();
  }

  Future<void> _deleteLocalModel() async {
    final shouldDelete = await ConfirmActionDialog.show(
      context,
      title: 'Delete local model?',
      message:
          'This removes the downloaded Gemma model from this device. Lilly will need to download it again.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
    );

    if (!shouldDelete) return;

    await _modelController?.shutdown();
    await _modelFileService.deleteModelIfExists();

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(SplashScreen.routeName, (route) => false);
  }

  Future<void> _startTriggerService() async {
    setState(() => _triggerBusy = true);
    await _triggerService.startForegroundTrigger();
    await _refreshModelDetails();
    if (mounted) {
      setState(() => _triggerBusy = false);
    }
  }

  Future<void> _stopTriggerService() async {
    setState(() => _triggerBusy = true);
    await _triggerService.stopForegroundTrigger();
    await _refreshModelDetails();
    if (mounted) {
      setState(() => _triggerBusy = false);
    }
  }

  String _statusLabel(ModelStatus? status) {
    switch (status) {
      case ModelStatus.loading:
        return 'Loading';
      case ModelStatus.ready:
        return 'Ready';
      case ModelStatus.error:
        return 'Error';
      case ModelStatus.uninitialized:
      default:
        return 'Not initialized';
    }
  }

  Color _statusColor(ModelStatus? status) {
    switch (status) {
      case ModelStatus.ready:
        return Colors.green;
      case ModelStatus.loading:
        return Colors.orange;
      case ModelStatus.error:
        return Colors.red;
      case ModelStatus.uninitialized:
      default:
        return Colors.grey;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
    return '${(bytes / mb).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: _modelController ?? ValueNotifier(0),
      builder: (context, _) {
        final modelStatus = _modelController?.status;
        final modelError = _modelController?.errorMessage;
        final modelInfo = _modelInfo;
        final trigger = _triggerCapabilities;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'App Preferences',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save chats locally'),
                      subtitle: const Text(
                        'Keep conversations on device for future viewing.',
                      ),
                      value: _saveChatsLocally,
                      onChanged: (value) async {
                        setState(() => _saveChatsLocally = value);
                        await _settingsService.setSaveChatsLocally(value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable image input'),
                      subtitle: const Text(
                        'Allow camera and gallery image attachments in chat.',
                      ),
                      value: _enableImageInput,
                      onChanged: (value) async {
                        setState(() => _enableImageInput = value);
                        await _settingsService.setEnableImageInput(value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show debug info'),
                      subtitle: const Text(
                        'Show model file details and runtime state.',
                      ),
                      value: _showDebugInfo,
                      onChanged: (value) async {
                        setState(() => _showDebugInfo = value);
                        await _settingsService.setShowDebugInfo(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Model',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Local model status'),
                      subtitle: Text(_statusLabel(modelStatus)),
                      trailing: Icon(
                        Icons.memory_rounded,
                        color: _statusColor(modelStatus),
                      ),
                    ),
                    if (modelInfo != null) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Model file'),
                        subtitle: Text(modelInfo.exists ? 'Present' : 'Missing'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Model size'),
                        subtitle: Text(_formatBytes(modelInfo.sizeBytes)),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Validation'),
                        subtitle: Text(
                          modelInfo.isValid ? 'Valid' : 'Missing or invalid',
                        ),
                      ),
                    ],
                    if (modelError != null && modelError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelectableText(
                          modelError,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (_modelController != null)
                          FilledButton.icon(
                            onPressed: _retryModelInit,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry model init'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _refreshModelDetails,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Refresh status'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _deleteLocalModel,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete local model'),
                        ),
                      ],
                    ),
                    if (_showDebugInfo && modelInfo != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Debug info',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        modelInfo.path,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Trigger & Background',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Android trigger scaffold'),
                      subtitle: Text(
                        trigger?.platformSupported == true
                            ? 'Available on this platform'
                            : 'Not supported on this platform',
                      ),
                    ),
                    if (trigger != null) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Foreground service'),
                        subtitle: Text(
                          trigger.isRunning ? 'Running' : 'Stopped',
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Wake word engine'),
                        subtitle: Text(
                          trigger.wakeWordReady
                              ? 'Connected'
                              : 'Groundwork only, not wired yet',
                        ),
                      ),
                      if (trigger.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SelectableText(
                            trigger.notes,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _triggerBusy || trigger.isRunning
                                ? null
                                : _startTriggerService,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start service'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _triggerBusy || !trigger.isRunning
                                ? null
                                : _stopTriggerService,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Stop service'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }
}
