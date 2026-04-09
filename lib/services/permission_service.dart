import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestPhotosPermission() async {
    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted || photosStatus.isLimited) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<bool> hasCameraPermission() async {
    return Permission.camera.isGranted;
  }

  Future<bool> hasPhotosPermission() async {
    final photosGranted = await Permission.photos.isGranted;
    final photosLimited = await Permission.photos.isLimited;
    final storageGranted = await Permission.storage.isGranted;

    return photosGranted || photosLimited || storageGranted;
  }
}
