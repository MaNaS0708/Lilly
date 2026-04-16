import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/model_setup_constants.dart';

class ModelFileInfo {
  const ModelFileInfo({
    required this.exists,
    required this.sizeBytes,
    required this.isValid,
    required this.path,
  });

  final bool exists;
  final int sizeBytes;
  final bool isValid;
  final String path;
}

class ModelFileService {
  Future<String> getModelDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> getModelPath() async {
    final dir = await getModelDirectoryPath();
    return '$dir/${ModelSetupConstants.modelFileName}';
  }

  Future<File> getModelFile() async {
    return File(await getModelPath());
  }

  Future<bool> modelExists() async {
    final file = await getModelFile();
    return file.exists();
  }

  Future<int> getModelSizeBytes() async {
    final file = await getModelFile();
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<bool> hasValidModelFile({bool strict = false}) async {
    final file = await getModelFile();
    if (!await file.exists()) return false;

    final size = await file.length();
    if (strict) {
      return size == ModelSetupConstants.expectedModelBytes;
    }

    return size >= ModelSetupConstants.minimumValidModelBytes;
  }

  Future<ModelFileInfo> inspectModelFile({bool strict = false}) async {
    final path = await getModelPath();
    final file = File(path);
    final exists = await file.exists();
    final sizeBytes = exists ? await file.length() : 0;
    final isValid = exists &&
        (strict
            ? sizeBytes == ModelSetupConstants.expectedModelBytes
            : sizeBytes >= ModelSetupConstants.minimumValidModelBytes);

    return ModelFileInfo(
      exists: exists,
      sizeBytes: sizeBytes,
      isValid: isValid,
      path: path,
    );
  }

  Future<void> deleteModelIfExists() async {
    final file = await getModelFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
