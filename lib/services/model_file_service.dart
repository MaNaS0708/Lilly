import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/model_setup_constants.dart';

class ModelFileService {
  Future<String> getModelDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> getModelPath() async {
    final dir = await getModelDirectoryPath();
    return '$dir/${ModelSetupConstants.modelFileName}';
  }

  Future<bool> modelExists() async {
    final file = File(await getModelPath());
    return file.exists();
  }

  Future<File> getModelFile() async {
    return File(await getModelPath());
  }

  Future<void> deleteModelIfExists() async {
    final file = File(await getModelPath());
    if (await file.exists()) {
      await file.delete();
    }
  }
}
