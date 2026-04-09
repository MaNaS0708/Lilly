import 'package:flutter/material.dart';

import '../controllers/model_controller.dart';
import '../models/model_status.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings';
  final ModelController? modelController;

  const SettingsScreen({super.key, this.modelController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  bool _saveChatsLocally = true;
  bool _enableImageInput = true;
  bool _showDebugInfo = false;
  bool _loading = true;

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

    setState(() {
      _saveChatsLocally = saveChats;
      _enableImageInput = enableImages;
      _showDebugInfo = showDebug;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final modelStatus = _modelController?.status;
    final modelError = _modelController?.errorMessage;

    return AnimatedBuilder(
      animation: _modelController ?? ValueNotifier(0),
      builder: (context, _) {
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
                        'Helpful later when integrating the local model.',
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
                    if (modelError != null && modelError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          modelError,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_modelController != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => _modelController!.initialize(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry model init'),
                        ),
                      ),
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
  final Widget child;

  const _SettingsCard({
    required this.child,
  });

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
