import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_downloader/flutter_downloader.dart';

import '../config/model_setup_constants.dart';
import 'model_file_service.dart';

class ModelDownloadSnapshot {
  final String? taskId;
  final DownloadTaskStatus status;
  final int progress;

  const ModelDownloadSnapshot({
    required this.taskId,
    required this.status,
    required this.progress,
  });
}

class ModelDownloadManager {
  ModelDownloadManager({
    ModelFileService? modelFileService,
  }) : _modelFileService = modelFileService ?? ModelFileService();

  final ModelFileService _modelFileService;
  final ReceivePort _port = ReceivePort();

  void initializePort(void Function(String, DownloadTaskStatus, int) onEvent) {
    IsolateNameServer.removePortNameMapping('lilly_downloader_send_port');
    IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'lilly_downloader_send_port',
    );

    _port.listen((dynamic data) {
      final id = data[0] as String;
      final status = DownloadTaskStatus.fromInt(data[1] as int);
      final progress = data[2] as int;
      onEvent(id, status, progress);
    });
  }

  void disposePort() {
    IsolateNameServer.removePortNameMapping('lilly_downloader_send_port');
    _port.close();
  }

  Future<String?> startDownload({String? accessToken}) async {
    final modelDir = await _modelFileService.getModelDirectoryPath();

    final headers = <String, String>{};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return FlutterDownloader.enqueue(
      url: ModelSetupConstants.modelUrl,
      savedDir: modelDir,
      fileName: ModelSetupConstants.modelFileName,
      headers: headers,
      showNotification: true,
      openFileFromNotification: false,
      saveInPublicStorage: false,
    );
  }

  Future<String?> resumeDownload(String taskId) async {
    return FlutterDownloader.resume(taskId: taskId);
  }

  Future<void> pauseDownload(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
  }

  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
  }

  Future<ModelDownloadSnapshot?> findTask(String taskId) async {
    final tasks = await FlutterDownloader.loadTasks() ?? [];
    for (final task in tasks) {
      if (task.taskId == taskId) {
        return ModelDownloadSnapshot(
          taskId: task.taskId,
          status: task.status,
          progress: task.progress,
        );
      }
    }
    return null;
  }
}
