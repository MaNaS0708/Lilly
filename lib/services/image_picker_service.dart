import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'permission_service.dart';

class ImagePickerService {
  ImagePickerService._();

  static final ImagePicker _picker = ImagePicker();
  static final PermissionService _permissionService = PermissionService();

  static Future<File?> pickFromCamera() async {
    final allowed = await _permissionService.requestCameraPermission();
    if (!allowed) {
      throw Exception('Camera permission was denied.');
    }

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (file == null) return null;
    return File(file.path);
  }

  static Future<File?> pickFromGallery() async {
    final allowed = await _permissionService.requestPhotosPermission();
    if (!allowed) {
      throw Exception('Photos permission was denied.');
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return null;
    return File(file.path);
  }
}
