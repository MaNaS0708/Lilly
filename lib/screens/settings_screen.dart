import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/model_controller.dart';
import '../models/model_status.dart';
import '../models/trigger_capabilities.dart';
import '../models/voice_language.dart';
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
  bool _triggerEnabled = false;
  String _voiceLanguageCode = VoiceLanguage.english.code;

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
    final triggerEnabled = await _settingsService.getTriggerEnabled();
    final voiceLanguageCode = await _settingsService
        .getPrimaryVoiceLanguageCode();
    final modelInfo = await _modelFileService.inspectModelFile(strict: true);
    final triggerCapabilities = await _triggerService.getCapabilities();

    if (!mounted) return;

    setState(() {
      _saveChatsLocally = saveChats;
      _enableImageInput = enableImages;
      _showDebugInfo = showDebug;
      _triggerEnabled = triggerEnabled;
      _voiceLanguageCode = voiceLanguageCode;
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
    await _modelFileService.deleteAllModelArtifacts();


    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(SplashScreen.routeName, (route) => false);
  }

  Future<void> _setVoiceLanguage(String code) async {
    await _settingsService.setPrimaryVoiceLanguageCode(code);
    await _modelController?.shutdown();

    if (!mounted) return;

    setState(() {
      _voiceLanguageCode = code;
    });

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(SplashScreen.routeName, (route) => false);
  }

  Future<bool> _ensureTriggerPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return false;
    }

    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted && !notificationStatus.isLimited) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification permission is recommended for the foreground service.',
          ),
        ),
      );
    }

    return true;
  }

  Future<void> _setTriggerEnabled(bool enabled) async {
    if (_triggerBusy) return;

    if (enabled) {
      final allowed = await _ensureTriggerPermissions();
      if (!allowed) return;
    }

    setState(() => _triggerBusy = true);

    await _settingsService.setTriggerEnabled(enabled);
    await _triggerService.setTriggerAutostart(enabled);

    if (enabled) {
      await _triggerService.startForegroundTrigger();
    } else {
      await _triggerService.stopForegroundTrigger();
    }

    await _refreshModelDetails();

    if (!mounted) return;
    setState(() {
      _triggerEnabled = enabled;
      _triggerBusy = false;
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
        return const Color(0xFF15803D);
      case ModelStatus.loading:
        return const Color(0xFFD97706);
      case ModelStatus.error:
        return const Color(0xFFDC2626);
      case ModelStatus.uninitialized:
      default:
        return const Color(0xFF6B7280);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedBuilder(
      animation: _modelController ?? ValueNotifier(0),
      builder: (context, _) {
        final modelStatus = _modelController?.status;
        final modelError = _modelController?.errorMessage;
        final modelInfo = _modelInfo;
        final trigger = _triggerCapabilities;
        final selectedLabel = VoiceLanguage.fromCode(_voiceLanguageCode).label;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle('Preferences'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save chats locally'),
                      subtitle: const Text(
                        'Keep conversations on this device.',
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
                        'Allow camera and gallery attachments.',
                      ),
                      value: _enableImageInput,
                      onChanged: (value) async {
                        setState(() => _enableImageInput = value);
                        await _settingsService.setEnableImageInput(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Voice Language'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speech language',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lilly will listen and reply in this language.',
                      style: TextStyle(color: Color(0xFF4B5563), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _voiceLanguageCode,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE9CAD4),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE9CAD4),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFC88298),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFFFBF8),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF776470),
                      ),
                      items: VoiceLanguage.values.map((language) {
                        return DropdownMenuItem<String>(
                          value: language.code,
                          child: Text(
                            language.label,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null && value != _voiceLanguageCode) {
                          _setVoiceLanguage(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Local Model'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      title: 'Status',
                      value: _statusLabel(modelStatus),
                      trailingColor: _statusColor(modelStatus),
                    ),
                    if (modelInfo != null) ...[
                      _InfoRow(
                        title: 'Gemma file',
                        value: modelInfo.exists ? 'Present' : 'Missing',
                      ),
                      _InfoRow(
                        title: 'Size',
                        value: _formatBytes(modelInfo.sizeBytes),
                      ),
                      _InfoRow(
                        title: 'Validation',
                        value: modelInfo.isValid
                            ? 'Valid'
                            : 'Missing or invalid',
                      ),
                    ],
                    if (modelError != null && modelError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: SelectableText(
                          modelError,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _retryModelInit,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reload Model'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _refreshModelDetails,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Check Status'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _deleteLocalModel,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete Model'),
                        ),
                      ],
                    ),
                    if (_showDebugInfo && modelInfo != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Debug path',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        modelInfo.path,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Assistant Trigger'),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Keep trigger active'),
                      subtitle: const Text(
                        'Runs a foreground service so Lilly can listen for “Hey Lilly” even when the app is closed.',
                      ),
                      value: _triggerEnabled,
                      onChanged: _triggerBusy ? null : _setTriggerEnabled,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      title: 'Foreground service',
                      value: trigger?.isRunning == true ? 'Running' : 'Stopped',
                    ),
                    _InfoRow(
                      title: 'Auto-restart',
                      value: trigger?.autostartEnabled == true
                          ? 'Enabled'
                          : 'Disabled',
                    ),
                    _InfoRow(
                      title: 'Trigger type',
                      value: 'Wake word -> voice chat',
                    ),
                    const SizedBox(height: 8),
                    if (trigger != null && trigger.notes.isNotEmpty)
                      SelectableText(
                        trigger.notes,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'How to use',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keep the trigger active, then say “Hey Lilly” to open Lilly directly in voice chat. While voice chat is running, the wake-word microphone pauses automatically and resumes after voice chat stops.',
                      style: TextStyle(color: Color(0xFF4B5563), height: 1.4),
                    ),
                   if (_triggerBusy) ...[
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onLongPress: () async {
                    setState(() => _showDebugInfo = !_showDebugInfo);
                    await _settingsService.setShowDebugInfo(_showDebugInfo);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _showDebugInfo
                                ? 'Debug info enabled'
                                : 'Debug info hidden',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Lilly v1.0',
                    style: TextStyle(
                      color: Color(0xFFAA9CA3),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E4E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F111827),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    this.trailingColor,
  });

  final String title;
  final String value;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailingColor != null) ...[
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: trailingColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
