import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class AutoCaptureCameraScreen extends StatefulWidget {
  const AutoCaptureCameraScreen({super.key});

  @override
  State<AutoCaptureCameraScreen> createState() =>
      _AutoCaptureCameraScreenState();
}

class _AutoCaptureCameraScreenState extends State<AutoCaptureCameraScreen> {
  CameraController? _controller;
  String? _errorMessage;
  bool _initializing = true;
  bool _capturing = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
        _initialized = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        await _capturePhoto();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(file.path));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _errorMessage = 'Could not capture the photo automatically.';
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blush = Color(0xFFF5D2DD);
    const cream = Color(0xFFFFFBF8);
    const text = Color(0xFF433040);
    const rose = Color(0xFFC9859B);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _initialized && _controller != null
                ? CameraPreview(_controller!)
                : Container(color: Colors.black),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: cream.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_initializing) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text(
                          'Opening camera and taking a photo...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (_capturing) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text(
                          'Capturing what is in front of you...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: text,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _setupCamera,
                          style: FilledButton.styleFrom(
                            backgroundColor: rose,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Try Again'),
                        ),
                      ] else ...[
                        const Text(
                          'Hold steady for a second',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Lilly will take the picture automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6B5A67),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _capturePhoto,
                          child: const Text('Capture Now'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 330,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: blush, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
