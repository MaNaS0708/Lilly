import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/model_setup_constants.dart';
import '../models/model_download_state.dart';
import '../services/hf_auth_service.dart';
import '../services/model_download_manager.dart';
import '../services/model_file_service.dart';
import '../services/model_setup_storage_service.dart';

class ModelSetupController extends ChangeNotifier {
  ModelSetupController({
    ModelFileService? modelFileService,
    ModelDownloadManager? modelDownloadManager,
    ModelSetupStorageService? storageService,
    HfAuthService? hfAuthService,
  }) : _modelFileService = modelFileService ?? ModelFileService(),
       _modelDownloadManager = modelDownloadManager ?? ModelDownloadManager(),
       _storageService = storageService ?? ModelSetupStorageService(),
       _hfAuthService = hfAuthService ?? HfAuthService() {
    _modelDownloadManager.initializePort(_onDownloadEvent);
  }

  final ModelFileService _modelFileService;
  final ModelDownloadManager _modelDownloadManager;
  final ModelSetupStorageService _storageService;
  final HfAuthService _hfAuthService;

  ModelDownloadState _state = ModelDownloadState.checking;
  double _progress = 0;
  String? _errorMessage;
  String? _accessToken;
  String? _taskId;

  ModelDownloadState get state => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  bool get canPause => _state == ModelDownloadState.downloading;
  bool get canRetry =>
      _state == ModelDownloadState.error ||
      _state == ModelDownloadState.needsDownload;
  bool get canCancel => _taskId != null;

  Future<void> initialize() async {
    _state = ModelDownloadState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      if (await _modelFileService.modelExists()) {
        _state = ModelDownloadState.ready;
        notifyListeners();
        return;
      }

      _taskId = await _storageService.loadTaskId();
      final storedToken = await _hfAuthService.getStoredToken();
      _accessToken = storedToken?.accessToken;

      if (_taskId != null) {
        final snapshot = await _modelDownloadManager.findTask(_taskId!);
        if (snapshot != null) {
          _progress = snapshot.progress / 100.0;

          switch (snapshot.status) {
            case DownloadTaskStatus.running:
            case DownloadTaskStatus.enqueued:
              _state = ModelDownloadState.downloading;
              notifyListeners();
              return;
            case DownloadTaskStatus.paused:
              _state = ModelDownloadState.error;
              _errorMessage = 'Download paused. Tap retry to resume.';
              notifyListeners();
              return;
            case DownloadTaskStatus.complete:
              _state = ModelDownloadState.ready;
              await _storageService.markCompleted(true);
              notifyListeners();
              return;
            default:
              break;
          }
        }
      }

      _state = ModelDownloadState.needsDownload;
      notifyListeners();
    } catch (e) {
      _state = ModelDownloadState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> startSetup() async {
    _errorMessage = null;
    notifyListeners();

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      await _startDownload();
      return;
    }

    await authenticateAndDownload();
  }

  Future<void> authenticateAndDownload() async {
    _state = ModelDownloadState.authenticating;
    _errorMessage = null;
    notifyListeners();

    final auth = await _hfAuthService.authenticate();

    if (!auth.success || auth.tokenData == null) {
      _state = ModelDownloadState.error;
      _errorMessage = auth.error ?? 'Authentication failed.';
      notifyListeners();
      return;
    }

    _accessToken = auth.tokenData!.accessToken;
    await _startDownload();
  }

  Future<void> _startDownload() async {
    _state = ModelDownloadState.downloading;
    _progress = 0;
    _errorMessage = null;
    notifyListeners();

    final taskId = await _modelDownloadManager.startDownload(
      accessToken: _accessToken,
    );

    if (taskId == null) {
      _state = ModelDownloadState.error;
      _errorMessage = 'Failed to start model download.';
      notifyListeners();
      return;
    }

    _taskId = taskId;
    await _storageService.saveTaskId(taskId);
  }

  Future<void> retryDownload() async {
    if (_taskId == null) {
      await startSetup();
      return;
    }

    final resumedTaskId = await _modelDownloadManager.resumeDownload(_taskId!);
    if (resumedTaskId == null) {
      _state = ModelDownloadState.error;
      _errorMessage = 'Unable to resume download.';
      notifyListeners();
      return;
    }

    _taskId = resumedTaskId;
    await _storageService.saveTaskId(resumedTaskId);
    _state = ModelDownloadState.downloading;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> cancelDownload() async {
    if (_taskId != null) {
      await _modelDownloadManager.cancelDownload(_taskId!);
    }
    await _modelFileService.deleteModelIfExists();
    await _storageService.reset();

    _taskId = null;
    _progress = 0;
    _state = ModelDownloadState.needsDownload;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> openLicensePage() async {
    await launchUrl(
      Uri.parse(ModelSetupConstants.modelCardUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> retryAfterLicenseAcceptance() async {
    await startSetup();
  }

  void _onDownloadEvent(String id, DownloadTaskStatus status, int progress) async {
    if (_taskId != id) return;

    _progress = progress / 100.0;

    switch (status) {
      case DownloadTaskStatus.running:
      case DownloadTaskStatus.enqueued:
        _state = ModelDownloadState.downloading;
        break;
      case DownloadTaskStatus.complete:
        _state = ModelDownloadState.ready;
        await _storageService.markCompleted(true);
        await _storageService.clearTaskId();
        _taskId = null;
        break;
      case DownloadTaskStatus.failed:
        _state = ModelDownloadState.error;
        _errorMessage = 'Download failed. Please retry.';
        await _storageService.clearTaskId();
        _taskId = null;
        break;
      case DownloadTaskStatus.paused:
        _state = ModelDownloadState.error;
        _errorMessage = 'Download paused. Tap retry to resume.';
        break;
      case DownloadTaskStatus.canceled:
        _state = ModelDownloadState.needsDownload;
        _progress = 0;
        await _storageService.clearTaskId();
        _taskId = null;
        break;
      default:
        break;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _modelDownloadManager.disposePort();
    super.dispose();
  }
}
