import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import '../config/model_setup_constants.dart';
import 'model_file_service.dart';

class ModelDownloadSnapshot {
  const ModelDownloadSnapshot({
    required this.taskId,
    required this.status,
    required this.progress,
  });

  final String? taskId;
  final DownloadTaskStatus status;
  final int progress;
}

class ModelDownloadManager {
  ModelDownloadManager({ModelFileService? modelFileService})
    : _modelFileService = modelFileService ?? ModelFileService();

  final ModelFileService _modelFileService;

  void Function(String, DownloadTaskStatus, int)? _eventListener;

  HttpClient? _client;
  IOSink? _sink;
  bool _cancelRequested = false;
  String? _activeTaskId;
  DownloadTaskStatus _activeStatus = DownloadTaskStatus.undefined;
  int _activeProgress = 0;

  void initializePort(void Function(String, DownloadTaskStatus, int) onEvent) {
    _eventListener = onEvent;
  }

  void disposePort() {
    _eventListener = null;
  }

  Future<String?> startDownload({String? accessToken}) async {
    if (_activeTaskId != null) {
      return _activeTaskId;
    }

    final taskId = 'gemma-${DateTime.now().millisecondsSinceEpoch}';
    _activeTaskId = taskId;
    _activeStatus = DownloadTaskStatus.enqueued;
    _activeProgress = 0;
    _cancelRequested = false;

    _emit(taskId, DownloadTaskStatus.enqueued, 0);
    unawaited(_runDownload(taskId, accessToken: accessToken));
    return taskId;
  }

  Future<void> cancelDownload(String taskId) async {
    if (_activeTaskId == taskId) {
      _cancelRequested = true;

      try {
        _client?.close(force: true);
      } catch (_) {}

      try {
        await _sink?.flush();
      } catch (_) {}

      try {
        await _sink?.close();
      } catch (_) {}

      await _deletePartialFile();
      _emit(taskId, DownloadTaskStatus.canceled, _activeProgress);
      _resetActiveState();
      return;
    }

    await removeTask(taskId, shouldDeleteContent: true);
  }

  Future<void> removeTask(
    String taskId, {
    bool shouldDeleteContent = true,
  }) async {
    if (_activeTaskId == taskId) {
      await cancelDownload(taskId);
      return;
    }

    if (shouldDeleteContent) {
      await _deletePartialFile();
    }
  }

  Future<void> removeAllModelTasks() async {
    if (_activeTaskId != null) {
      await cancelDownload(_activeTaskId!);
    } else {
      await _deletePartialFile();
    }
  }

  Future<void> removeInactiveModelTasks() async {
    if (_activeTaskId == null) {
      await _deletePartialFile();
      return;
    }

    final isActive =
        _activeStatus == DownloadTaskStatus.running ||
        _activeStatus == DownloadTaskStatus.enqueued;

    if (!isActive) {
      await _deletePartialFile();
      _resetActiveState();
    }
  }

  Future<ModelDownloadSnapshot?> findTask(String taskId) async {
    if (_activeTaskId == taskId) {
      return ModelDownloadSnapshot(
        taskId: _activeTaskId,
        status: _activeStatus,
        progress: _activeProgress,
      );
    }
    return null;
  }

  Future<ModelDownloadSnapshot?> findAnyModelTask() async {
    if (_activeTaskId == null) return null;

    return ModelDownloadSnapshot(
      taskId: _activeTaskId,
      status: _activeStatus,
      progress: _activeProgress,
    );
  }

  Future<String> debugDescribeTasks() async {
    if (_activeTaskId == null) return 'No in-app download task';
    return 'taskId=$_activeTaskId status=$_activeStatus progress=$_activeProgress';
  }

  Future<void> _runDownload(
    String taskId, {
    String? accessToken,
  }) async {
    final targetPath = await _modelFileService.getModelPath();
    final partialPath = '$targetPath.partial';
    final targetFile = File(targetPath);
    final partialFile = File(partialPath);

    try {
      await partialFile.parent.create(recursive: true);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }

      _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);

      final request = await _client!.getUrl(
        Uri.parse(ModelSetupConstants.modelUrl),
      );

      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Gemma download failed with HTTP ${response.statusCode}.',
        );
      }

      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      _sink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);
      _emit(taskId, DownloadTaskStatus.running, 0);

      await for (final chunk in response) {
        if (_cancelRequested) {
          throw const _CanceledDownloadException();
        }

        _sink!.add(chunk);
        downloadedBytes += chunk.length;

        final progress = totalBytes > 0
            ? ((downloadedBytes / totalBytes) * 100).clamp(0, 99).toInt()
            : 0;

        _emit(taskId, DownloadTaskStatus.running, progress);
      }

      await _sink!.flush();
      await _sink!.close();
      _sink = null;
      _client?.close(force: false);
      _client = null;

      if (_cancelRequested) {
        throw const _CanceledDownloadException();
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await partialFile.rename(targetPath);
      _emit(taskId, DownloadTaskStatus.complete, 100);
    } on _CanceledDownloadException {
      debugPrint('[LillySetup] In-app Gemma download canceled.');
      await _deletePartialFile();
      _emit(taskId, DownloadTaskStatus.canceled, _activeProgress);
    } catch (e) {
      debugPrint('[LillySetup] In-app Gemma download failed: $e');
      await _deletePartialFile();
      _emit(taskId, DownloadTaskStatus.failed, _activeProgress);
    } finally {
      try {
        _client?.close(force: true);
      } catch (_) {}

      try {
        await _sink?.close();
      } catch (_) {}

      _client = null;
      _sink = null;
      _resetActiveState();
    }
  }

  Future<void> _deletePartialFile() async {
    final partial = File('${await _modelFileService.getModelPath()}.partial');
    if (await partial.exists()) {
      try {
        await partial.delete();
      } catch (_) {}
    }
  }

  void _emit(String taskId, DownloadTaskStatus status, int progress) {
    _activeTaskId = taskId;
    _activeStatus = status;
    _activeProgress = progress;
    _eventListener?.call(taskId, status, progress);
  }

  void _resetActiveState() {
    _cancelRequested = false;
    _activeTaskId = null;
    _activeStatus = DownloadTaskStatus.undefined;
    _activeProgress = 0;
  }
}

class _CanceledDownloadException implements Exception {
  const _CanceledDownloadException();
}
