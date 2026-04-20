import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/model_setup_constants.dart';
import '../models/voice_language.dart';

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

  Future<String> getVoskArchivePath(String languageCode) async {
    final dir = await getModelDirectoryPath();
    final language = VoiceLanguage.fromCode(languageCode);
    return '$dir/${language.voskArchiveFileName}';
  }

  Future<File> getVoskArchiveFile(String languageCode) async {
    return File(await getVoskArchivePath(languageCode));
  }

  Future<String> getVoskModelPath(String languageCode) async {
    final dir = await getModelDirectoryPath();
    final language = VoiceLanguage.fromCode(languageCode);
    return '$dir/${language.voskDirectoryName}';
  }

  Future<Directory> getVoskModelDirectory(String languageCode) async {
    return Directory(await getVoskModelPath(languageCode));
  }

  Future<bool> voskModelExists(String languageCode) async {
    final dir = await getVoskModelDirectory(languageCode);
    return dir.exists();
  }

  Future<bool> hasValidVoskModel(String languageCode) async {
    final dir = await getVoskModelDirectory(languageCode);
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

  Future<ModelFileInfo> inspectVoskModel(String languageCode) async {
    final path = await getVoskModelPath(languageCode);
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

    final isValid = exists && await hasValidVoskModel(languageCode);

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

  Future<void> deleteVoskIfExists(String languageCode) async {
    final archive = await getVoskArchiveFile(languageCode);
    if (await archive.exists()) {
      await archive.delete();
    }

    final dir = await getVoskModelDirectory(languageCode);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> deleteUnusedVoiceModels(Iterable<String> keepCodes) async {
    final keep = keepCodes.toSet();

    for (final language in VoiceLanguage.values) {
      if (!keep.contains(language.code)) {
        await deleteVoskIfExists(language.code);
      }
    }
  }

  Future<bool> hasAllRuntimeModels({
    required Iterable<String> voiceLanguageCodes,
  }) async {
    final gemma = await hasValidModelFile(strict: true);
    if (!gemma) return false;

    for (final code in voiceLanguageCodes) {
      if (!await hasValidVoskModel(code)) {
        return false;
      }
    }

    return true;
  }
}
