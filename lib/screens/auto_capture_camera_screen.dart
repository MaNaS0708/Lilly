import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AutoCaptureCameraScreen extends StatefulWidget {
  final void Function(File imageFile) onImageCaptured;
  final Duration captureDelay;

  const AutoCaptureCameraScreen({
    super.key,
    required this.onImageCaptured,
    this.captureDelay = const Duration(milliseconds: 1500),
  });

  @override
  State<AutoCaptureCameraScreen> createState() =>
      _AutoCaptureCameraScreenState();
}

class _AutoCaptureCameraScreenState extends State<AutoCaptureCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _capturing = false;
  bool _disposed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _handleError('No camera found on this device.');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (_disposed) {
        controller.dispose();
        return;
      }

      if (mounted) {
        setState(() => _controller = controller);
      }

      HapticFeedback.mediumImpact();
      Future.delayed(widget.captureDelay, _capturePhoto);
    } catch (e) {
      await _handleError('Could not open camera. $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_capturing || _disposed) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _capturing = true;

    try {
      final xFile = await controller.takePicture();
      final imageFile = File(xFile.path);

      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      HapticFeedback.heavyImpact();

      if (!_disposed) {
        widget.onImageCaptured(imageFile);
        if (mounted) {
          Navigator.of(context).pop(imageFile);
        }
      }
    } catch (e) {
      await _handleError('Could not take photo. Tap to try again.');
      _capturing = false;
    }
  }

  Future<void> _handleError(String message) async {
    HapticFeedback.vibrate();
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _ErrorView(
        message: _errorMessage!,
        onRetry: () {
          setState(() {
            _errorMessage = null;
            _capturing = false;
          });
          _setupCamera();
        },
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        GestureDetector(
          onDoubleTap: _capturePhoto,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Double-tap anywhere to capture',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _capturing ? null : _capturePhoto,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: _capturing
                            ? Colors.white38
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                      child: _capturing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white38,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
