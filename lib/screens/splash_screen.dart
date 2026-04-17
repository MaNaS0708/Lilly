import 'package:flutter/material.dart';

import '../config/model_setup_constants.dart';
import '../controllers/model_setup_controller.dart';
import '../models/model_download_state.dart';
import 'chat_screen.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final ModelSetupController _modelSetupController;

  @override
  void initState() {
    super.initState();
    _modelSetupController = ModelSetupController()..addListener(_onStateChanged);
    _modelSetupController.initialize();
  }

  @override
  void dispose() {
    _modelSetupController.removeListener(_onStateChanged);
    _modelSetupController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;

    if (_modelSetupController.state == ModelDownloadState.ready) {
      Navigator.of(context).pushReplacementNamed(ChatScreen.routeName);
    } else {
      setState(() {});
    }
  }

  Future<void> _handlePrimaryAction() async {
    switch (_modelSetupController.state) {
      case ModelDownloadState.needsDownload:
      case ModelDownloadState.error:
        await _modelSetupController.startSetup();
        break;
      case ModelDownloadState.awaitingLicenseAcceptance:
        await _modelSetupController.openLicensePage();
        break;
      default:
        break;
    }
  }

  Future<void> _handleSecondaryAction() async {
    if (_modelSetupController.state ==
        ModelDownloadState.awaitingLicenseAcceptance) {
      await _modelSetupController.retryAfterLicenseAcceptance();
      return;
    }

    if (_modelSetupController.canCancel) {
      await _modelSetupController.cancelDownload();
    }
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
        return _modelSetupController.phaseLabel;
      case ModelDownloadState.ready:
        return 'Ready';
      case ModelDownloadState.error:
        return 'Setup Failed';
    }
  }

  String _messageForState(ModelDownloadState state) {
    switch (state) {
      case ModelDownloadState.checking:
        return 'Checking Gemma and offline voice models on this device.';
      case ModelDownloadState.needsDownload:
        return 'Lilly will download Gemma plus the offline voice model during setup.';
      case ModelDownloadState.authenticating:
        return 'Sign in to Hugging Face so Lilly can access the Gemma model.';
      case ModelDownloadState.awaitingLicenseAcceptance:
        return 'Open the model page, accept the license, then come back here and continue.';
      case ModelDownloadState.downloading:
        return _modelSetupController.phaseLabel;
      case ModelDownloadState.ready:
        return 'All models are ready.';
      case ModelDownloadState.error:
        return _modelSetupController.errorMessage ??
            'Something went wrong during setup.';
    }
  }

  String? _primaryLabel() {
    switch (_modelSetupController.state) {
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
    if (_modelSetupController.state ==
        ModelDownloadState.awaitingLicenseAcceptance) {
      return 'I Accepted The License';
    }
    if (_modelSetupController.canCancel) {
      return 'Cancel Download';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = _modelSetupController.state;
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
                        value: _modelSetupController.progress == 0
                            ? null
                            : _modelSetupController.progress,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_modelSetupController.progress * 100).toStringAsFixed(0)}%',
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
}
