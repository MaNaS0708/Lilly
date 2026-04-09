import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ModelFileService {
  static const String modelFileName = 'gemma-4-model.task';

  Future<String> getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$modelFileName';
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
