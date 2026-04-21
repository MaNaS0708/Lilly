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
  final Set<String> _selectedLanguageCodes = <String>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storedLanguages = await _settingsService.getVoiceLanguageCodes();

    if (!mounted) return;

    if (storedLanguages.isEmpty) {
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
    if (_selectedLanguageCodes.isEmpty) return;

    await _settingsService.setVoiceLanguageCodes(_selectedLanguageCodes.toList());

    if (!mounted) return;
    _startModelSetup();
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
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Choose Voice Languages',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Select one or more speech languages. Lilly will download Gemma once, then use phone speech recognition and spoken replies for voice chat.',
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
                      ),
                      child: Column(
                        children: VoiceLanguage.values.map((language) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(language.label),
                            value: _selectedLanguageCodes.contains(language.code),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedLanguageCodes.add(language.code);
                                } else {
                                  _selectedLanguageCodes.remove(language.code);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _selectedLanguageCodes.isEmpty
                            ? null
                            : _confirmLanguageSelection,
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
    final controller = _modelSetupController!;
    final state = controller.state;

    String? primaryLabel() {
      switch (state) {
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

    String? secondaryLabel() {
      if (state == ModelDownloadState.awaitingLicenseAcceptance) {
        return 'I Accepted The License';
      }
      if (controller.canCancel) {
        return 'Cancel Download';
      }
      return null;
    }

    String messageForState() {
      switch (state) {
        case ModelDownloadState.checking:
          return 'Checking the Gemma model and your selected speech languages on this device.';
        case ModelDownloadState.needsDownload:
          return 'Selected languages: ${controller.requiredVoiceLanguageSummary}';
        case ModelDownloadState.authenticating:
          return 'Sign in to Hugging Face so Lilly can access the Gemma model.';
        case ModelDownloadState.awaitingLicenseAcceptance:
          return 'Open the model page, accept the license, then come back here.';
        case ModelDownloadState.downloading:
          return '${controller.phaseLabel}\nCurrent file: ${controller.activeModelLabel}';
        case ModelDownloadState.ready:
          return 'Gemma is ready. Voice chat will use your phone speech recognition and spoken replies.';
        case ModelDownloadState.error:
          return controller.errorMessage ?? 'Something went wrong during setup.';
      }
    }

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
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_rounded, size: 56),
                    const SizedBox(height: 24),
                    Text(
                      controller.phaseLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      messageForState(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.5),
                    ),
                    if (state == ModelDownloadState.downloading) ...[
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: controller.progress == 0
                            ? null
                            : controller.progress,
                      ),
                      const SizedBox(height: 10),
                      Text('${(controller.progress * 100).toStringAsFixed(0)}%'),
                    ],
                    const SizedBox(height: 24),
                    if (primaryLabel() != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _handlePrimaryAction,
                          child: Text(primaryLabel()!),
                        ),
                      ),
                    if (secondaryLabel() != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          onPressed: _handleSecondaryAction,
                          child: Text(secondaryLabel()!),
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
