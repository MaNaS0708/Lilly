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
            colors: [Color(0xFFFFFBF8), Color(0xFFF5D7E2), Color(0xFFFDF7F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22C88298),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/lilly_logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Welcome to Lilly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF473241),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Choose the speech languages you want Lilly to use.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.55,
                        color: Color(0xFF776470),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE9CAD4)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            18,
                            0,
                            18,
                            14,
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          title: const Text(
                            'Voice Languages',
                            style: TextStyle(
                              color: Color(0xFF473241),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _selectedLanguageCodes.isEmpty
                                ? 'Tap to choose languages'
                                : '${_selectedLanguageCodes.length} selected',
                            style: const TextStyle(
                              color: Color(0xFF776470),
                            ),
                          ),
                          children: VoiceLanguage.values.map((language) {
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFFC88298),
                              title: Text(
                                language.label,
                                style: const TextStyle(
                                  color: Color(0xFF473241),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _selectedLanguageCodes.contains(
                                language.code,
                              ),
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
          return 'Gemma is ready. Lilly can now chat by voice and read visible text around you.';
        case ModelDownloadState.error:
          return controller.errorMessage ?? 'Something went wrong during setup.';
      }
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFBF8), Color(0xFFF5D7E2), Color(0xFFFDF7F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/lilly_logo.jpg',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      controller.phaseLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF473241),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      messageForState(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.55,
                        color: Color(0xFF776470),
                      ),
                    ),
                    if (state == ModelDownloadState.downloading) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: controller.progress == 0
                              ? null
                              : controller.progress,
                          backgroundColor: const Color(0xFFF3E1E8),
                          color: const Color(0xFFC88298),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(controller.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFF473241),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
