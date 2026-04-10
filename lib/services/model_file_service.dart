import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/model_setup_constants.dart';

class ModelFileService {
  Future<String> getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${ModelSetupConstants.modelFileName}';
  }

  Future<bool> modelExists() async {
    final path = await getModelPath();
    final file = File(path);
    return file.exists();
  }

  Future<File> getModelFile() async {
    final path = await getModelPath();
    return File(path);
  }
}
