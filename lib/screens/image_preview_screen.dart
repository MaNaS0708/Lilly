import 'dart:io';

import 'package:flutter/material.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String imagePath;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white70,
                    size: 60,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Could not load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
