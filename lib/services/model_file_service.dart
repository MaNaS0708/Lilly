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
    final isValid =
        exists &&
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

  Future<void> deleteLegacyVoiceAssets() async {
    final dir = await getModelDirectoryPath();
    const legacyNames = [
      'vosk-model-small-en-us-0.15',
      'vosk-model-small-hi-0.22',
      'vosk-model-small-es-0.42',
      'vosk-model-small-fr-0.22',
      'vosk-model-small-de-0.15',
      'vosk-model-small-pt-0.3',
      'vosk-model-small-ru-0.22',
      'vosk-model-small-en-us-0.15.zip',
      'vosk-model-small-hi-0.22.zip',
      'vosk-model-small-es-0.42.zip',
      'vosk-model-small-fr-0.22.zip',
      'vosk-model-small-de-0.15.zip',
      'vosk-model-small-pt-0.3.zip',
      'vosk-model-small-ru-0.22.zip',
    ];

    for (final name in legacyNames) {
      final path = '$dir/$name';
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        continue;
      }

      final legacyDir = Directory(path);
      if (await legacyDir.exists()) {
        await legacyDir.delete(recursive: true);
      }
    }
  }

  Future<bool> hasAllRuntimeModels({
    required Iterable<String> voiceLanguageCodes,
  }) async {
    return hasValidModelFile(strict: true);
  }
}
