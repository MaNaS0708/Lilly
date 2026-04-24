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
  static const _modelDirName = 'lilly_models';

  Future<Directory> _getModelDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_modelDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> getModelDirectoryPath() async {
    return (await _getModelDirectory()).path;
  }

  Future<String> getModelPath() async {
    final dir = await _getModelDirectory();
    return '${dir.path}/${ModelSetupConstants.modelFileName}';
  }

  Future<File> getModelFile() async {
    return File(await getModelPath());
  }

  Future<File> _getLegacyModelFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/${ModelSetupConstants.modelFileName}');
  }

  Future<File?> _locateExistingModelFile() async {
    final current = await getModelFile();
    if (await current.exists()) {
      return current;
    }

    final legacy = await _getLegacyModelFile();
    if (await legacy.exists()) {
      return legacy;
    }

    return null;
  }

  Future<bool> hasValidModelFile({bool strict = false}) async {
    final file = await _locateExistingModelFile();
    if (file == null || !await file.exists()) return false;

    final size = await file.length();
    if (strict) {
      return size == ModelSetupConstants.expectedModelBytes;
    }

    return size >= ModelSetupConstants.minimumValidModelBytes;
  }

  Future<ModelFileInfo> inspectModelFile({bool strict = false}) async {
    final existing = await _locateExistingModelFile();
    final targetPath = existing?.path ?? await getModelPath();
    final exists = existing != null && await existing.exists();
    final sizeBytes = exists ? await existing.length() : 0;
    final isValid =
        exists &&
        (strict
            ? sizeBytes == ModelSetupConstants.expectedModelBytes
            : sizeBytes >= ModelSetupConstants.minimumValidModelBytes);

    return ModelFileInfo(
      exists: exists,
      sizeBytes: sizeBytes,
      isValid: isValid,
      path: targetPath,
    );
  }

  Future<void> deleteModelIfExists() async {
    final current = await getModelFile();
    if (await current.exists()) {
      await current.delete();
    }

    final legacy = await _getLegacyModelFile();
    if (await legacy.exists()) {
      await legacy.delete();
    }
  }

  Future<void> deleteAllModelArtifacts() async {
    await deleteModelIfExists();

    final currentDir = await _getModelDirectory();
    await _deleteArtifactsInside(currentDir);

    final docs = await getApplicationDocumentsDirectory();
    await _deleteArtifactsInside(Directory(docs.path));
  }

  Future<void> _deleteArtifactsInside(Directory dir) async {
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is! File) continue;

      final name = entity.path.split('/').last.toLowerCase();
      final looksLikeGemmaArtifact =
          name == ModelSetupConstants.modelFileName.toLowerCase() ||
          name.startsWith(
            ModelSetupConstants.modelFileName.toLowerCase(),
          ) ||
          name.contains('gemma-4-e4b-it') ||
          name.contains('.litertlm') ||
          (name.contains('gemma') && name.endsWith('.part')) ||
          (name.contains('gemma') && name.endsWith('.partial')) ||
          (name.contains('gemma') && name.endsWith('.tmp')) ||
          (name.contains('gemma') && name.endsWith('.temp'));

      if (looksLikeGemmaArtifact) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteLegacyVoiceAssets() async {
    final docs = await getApplicationDocumentsDirectory();
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
      final path = '${docs.path}/$name';
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
