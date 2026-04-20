import 'package:flutter/material.dart';

import '../controllers/model_setup_controller.dart';
import '../models/model_download_state.dart';
import '../models/voice_language.dart';
import '../services/settings_service.dart';
import 'chat_screen.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SettingsService _settingsService = SettingsService();

  ModelSetupController? _modelSetupController;
  bool _loadingBootstrap = true;
  bool _needsLanguageSelection = false;
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storedLanguage = await _settingsService.getVoiceLanguageCode();

    if (!mounted) return;

    if (storedLanguage == null) {
      setState(() {
        _loadingBootstrap = false;
        _needsLanguageSelection = true;
      });
      return;
    }

    _startModelSetup();
  }

  void _startModelSetup() {
    _modelSetupController?.removeListener(_onStateChanged);
    _modelSetupController?.dispose();

    final controller = ModelSetupController()..addListener(_onStateChanged);

    setState(() {
      _modelSetupController = controller;
      _loadingBootstrap = false;
      _needsLanguageSelection = false;
    });

    controller.initialize();
  }

  @override
  void dispose() {
    _modelSetupController?.removeListener(_onStateChanged);
    _modelSetupController?.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted || _modelSetupController == null) return;

    if (_modelSetupController!.state == ModelDownloadState.ready) {
      Navigator.of(context).pushReplacementNamed(ChatScreen.routeName);
    } else {
      setState(() {});
    }
  }

  Future<void> _handlePrimaryAction() async {
    final controller = _modelSetupController;
    if (controller == null) return;

    switch (controller.state) {
      case ModelDownloadState.needsDownload:
      case ModelDownloadState.error:
        await controller.startSetup();
        break;
      case ModelDownloadState.awaitingLicenseAcceptance:
        await controller.openLicensePage();
        break;
      default:
        break;
    }
  }

  Future<void> _handleSecondaryAction() async {
    final controller = _modelSetupController;
    if (controller == null) return;

    if (controller.state == ModelDownloadState.awaitingLicenseAcceptance) {
      await controller.retryAfterLicenseAcceptance();
      return;
    }

    if (controller.canCancel) {
      await controller.cancelDownload();
    }
  }

  Future<void> _confirmLanguageSelection() async {
    if (_selectedLanguageCode == null) return;

    await _settingsService.setVoiceLanguageCode(_selectedLanguageCode!);

    if (!mounted) return;
    _startModelSetup();
  }

  String _titleForState(ModelDownloadState state) {
    switch (state) {
      case ModelDownloadState.checking:
        return 'Preparing Lilly';
      case ModelDownloadState.needsDownload:
        return 'Model Setup Required';
      case ModelDownloadState.authenticating:
        return 'Connecting to Hugging Face';
      case ModelDownloadState.awaitingLicenseAcceptance:
        return 'Accept Model License';
      case ModelDownloadState.downloading:
        return _modelSetupController?.phaseLabel ?? 'Downloading';
      case ModelDownloadState.ready:
        return 'Ready';
      case ModelDownloadState.error:
        return 'Setup Failed';
    }
  }

  String _messageForState(ModelDownloadState state) {
    final controller = _modelSetupController;

    switch (state) {
      case ModelDownloadState.checking:
        return 'Checking the multilingual Gemma model and your selected voice model on this device.';
      case ModelDownloadState.needsDownload:
        return 'Lilly will download one multilingual Gemma model plus your selected offline voice model.';
      case ModelDownloadState.authenticating:
        return 'Sign in to Hugging Face so Lilly can access the Gemma model.';
      case ModelDownloadState.awaitingLicenseAcceptance:
        return 'Open the model page, accept the license, then come back here and continue.';
      case ModelDownloadState.downloading:
        return controller?.phaseLabel ?? 'Downloading...';
      case ModelDownloadState.ready:
        return 'Gemma and your voice model are ready.';
      case ModelDownloadState.error:
        return controller?.errorMessage ??
            'Something went wrong during setup.';
    }
  }

  String? _primaryLabel() {
    final controller = _modelSetupController;
    if (controller == null) return null;

    switch (controller.state) {
      case ModelDownloadState.needsDownload:
        return 'Start Setup';
      case ModelDownloadState.awaitingLicenseAcceptance:
        return 'Open License Page';
      case ModelDownloadState.error:
        return 'Try Again';
      default:
        return null;
    }
  }

  String? _secondaryLabel() {
    final controller = _modelSetupController;
    if (controller == null) return null;

    if (controller.state == ModelDownloadState.awaitingLicenseAcceptance) {
      return 'I Accepted The License';
    }
    if (controller.canCancel) {
      return 'Cancel Download';
    }
    return null;
  }

  Widget _buildLanguageSelection() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F8FA), Color(0xFFEFF2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Choose Voice Language',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pick the offline speech language Lilly should download first. Only that voice pack will be downloaded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A111827),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: VoiceLanguage.values.map((language) {
                          final selected = _selectedLanguageCode == language.code;
                          return RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(language.label),
                            value: language.code,
                            groupValue: _selectedLanguageCode,
                            onChanged: (value) {
                              setState(() {
                                _selectedLanguageCode = value;
                              });
                            },
                            selected: selected,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _selectedLanguageCode == null
                            ? null
                            : _confirmLanguageSelection,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    final controller = _modelSetupController;
    if (controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = controller.state;
    final primaryLabel = _primaryLabel();
    final secondaryLabel = _secondaryLabel();

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F8FA), Color(0xFFEFF2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: state == ModelDownloadState.checking ||
                              state == ModelDownloadState.authenticating ||
                              state == ModelDownloadState.downloading
                          ? const Padding(
                              padding: EdgeInsets.all(26),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.visibility_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _titleForState(state),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _messageForState(state),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (state == ModelDownloadState.downloading) ...[
                      const SizedBox(height: 28),
                      LinearProgressIndicator(
                        value: controller.progress == 0
                            ? null
                            : controller.progress,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(controller.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (primaryLabel != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _handlePrimaryAction,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(primaryLabel),
                        ),
                      ),
                    if (secondaryLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          onPressed: _handleSecondaryAction,
                          child: Text(secondaryLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBootstrap) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsLanguageSelection) {
      return _buildLanguageSelection();
    }

    return _buildSetupScreen();
  }
}
