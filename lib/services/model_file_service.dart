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

  Future<String> getVoskArchivePath() async {
    final dir = await getModelDirectoryPath();
    return '$dir/${ModelSetupConstants.voskArchiveFileName}';
  }

  Future<File> getVoskArchiveFile() async {
    return File(await getVoskArchivePath());
  }

  Future<String> getVoskModelPath() async {
    final dir = await getModelDirectoryPath();
    return '$dir/${ModelSetupConstants.voskModelDirectoryName}';
  }

  Future<Directory> getVoskModelDirectory() async {
    return Directory(await getVoskModelPath());
  }

  Future<bool> voskModelExists() async {
    final dir = await getVoskModelDirectory();
    return dir.exists();
  }

  Future<bool> hasValidVoskModel() async {
    final dir = await getVoskModelDirectory();
    if (!await dir.exists()) return false;

    final requiredPaths = [
      '${dir.path}/am/final.mdl',
      '${dir.path}/conf/mfcc.conf',
      '${dir.path}/graph/Gr.fst',
      '${dir.path}/graph/words.txt',
    ];

    for (final path in requiredPaths) {
      if (!await File(path).exists()) {
        return false;
      }
    }

    return true;
  }

  Future<ModelFileInfo> inspectVoskModel() async {
    final path = await getVoskModelPath();
    final dir = Directory(path);
    final exists = await dir.exists();

    var sizeBytes = 0;
    if (exists) {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          sizeBytes += await entity.length();
        }
      }
    }

    final isValid = exists && await hasValidVoskModel();

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

  Future<void> deleteVoskIfExists() async {
    final archive = await getVoskArchiveFile();
    if (await archive.exists()) {
      await archive.delete();
    }

    final dir = await getVoskModelDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<bool> hasAllRuntimeModels() async {
    final gemma = await hasValidModelFile(strict: true);
    final vosk = await hasValidVoskModel();
    return gemma && vosk;
  }
}
