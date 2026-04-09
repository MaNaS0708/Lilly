import 'package:flutter/material.dart';

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
        await _modelSetupController.authenticateAndDownload();
        break;
      case ModelDownloadState.awaitingLicenseAcceptance:
        await _modelSetupController.openLicensePage();
        break;
      case ModelDownloadState.error:
        await _modelSetupController.initialize();
        break;
      default:
        break;
    }
  }

  Future<void> _handleSecondaryAction() async {
    if (_modelSetupController.state ==
        ModelDownloadState.awaitingLicenseAcceptance) {
      await _modelSetupController.retryAfterLicenseAcceptance();
    }
  }

  String _titleForState(ModelDownloadState state) {
    switch (state) {
      case ModelDownloadState.checking:
        return 'Preparing Lilly';
      case ModelDownloadState.needsDownload:
        return 'Model Download Required';
      case ModelDownloadState.authenticating:
        return 'Connecting to Hugging Face';
      case ModelDownloadState.awaitingLicenseAcceptance:
        return 'Accept Model License';
      case ModelDownloadState.downloading:
        return 'Downloading Model';
      case ModelDownloadState.ready:
        return 'Ready';
      case ModelDownloadState.error:
        return 'Setup Failed';
    }
  }

  String _messageForState(ModelDownloadState state) {
    switch (state) {
      case ModelDownloadState.checking:
        return 'Checking whether your offline Gemma model is already available on this device.';
      case ModelDownloadState.needsDownload:
        return 'This app needs to download the model once. After that, chat works fully offline.';
      case ModelDownloadState.authenticating:
        return 'Sign in to Hugging Face so the app can access the Gemma model.';
      case ModelDownloadState.awaitingLicenseAcceptance:
        return 'You need to accept the model license on Hugging Face before download can continue.';
      case ModelDownloadState.downloading:
        return 'The model is downloading now. This may take a while depending on your connection.';
      case ModelDownloadState.ready:
        return 'Model is ready.';
      case ModelDownloadState.error:
        return _modelSetupController.errorMessage ??
            'Something went wrong during setup.';
    }
  }

  Widget _buildPrimaryButton() {
    final state = _modelSetupController.state;

    switch (state) {
      case ModelDownloadState.needsDownload:
        return _ActionButton(
          label: 'Continue',
          onPressed: _handlePrimaryAction,
        );
      case ModelDownloadState.awaitingLicenseAcceptance:
        return _ActionButton(
          label: 'Open License Page',
          onPressed: _handlePrimaryAction,
        );
      case ModelDownloadState.error:
        return _ActionButton(
          label: 'Retry',
          onPressed: _handlePrimaryAction,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSecondaryButton() {
    if (_modelSetupController.state !=
        ModelDownloadState.awaitingLicenseAcceptance) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton(
        onPressed: _handleSecondaryAction,
        child: const Text('I Accepted The License'),
      ),
    );
  }

  Widget _buildProgressSection() {
    if (_modelSetupController.state != ModelDownloadState.downloading) {
      return const SizedBox.shrink();
    }

    final progress = _modelSetupController.progress;

    return Column(
      children: [
        const SizedBox(height: 28),
        LinearProgressIndicator(value: progress == 0 ? null : progress),
        const SizedBox(height: 10),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTopVisual() {
    final state = _modelSetupController.state;
    final busy = state == ModelDownloadState.checking ||
        state == ModelDownloadState.authenticating ||
        state == ModelDownloadState.downloading;

    return Container(
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
            color: const Color(0xFF4F46E5).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: busy
          ? const Padding(
              padding: EdgeInsets.all(26),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(
              Icons.visibility_rounded,
              color: Colors.white,
              size: 44,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _modelSetupController.state;

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
                    _buildTopVisual(),
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
                    _buildProgressSection(),
                    const SizedBox(height: 28),
                    _buildPrimaryButton(),
                    _buildSecondaryButton(),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }
}
