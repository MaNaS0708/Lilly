import 'dart:io';

import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  ImagePickerService._();

  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (file == null) return null;
    return File(file.path);
  }

  static Future<File?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return null;
    return File(file.path);
  }
}
