import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/model_setup_constants.dart';
import '../models/model_download_state.dart';
import '../services/hf_auth_service.dart';
import '../services/model_download_manager.dart';
import '../services/model_download_service.dart';
import '../services/model_file_service.dart';
import '../services/model_setup_storage_service.dart';

class ModelSetupController extends ChangeNotifier {
  ModelSetupController({
    ModelFileService? modelFileService,
    ModelDownloadManager? modelDownloadManager,
    ModelDownloadService? modelDownloadService,
    ModelSetupStorageService? storageService,
    HfAuthService? hfAuthService,
  }) : _modelFileService = modelFileService ?? ModelFileService(),
       _modelDownloadManager = modelDownloadManager ?? ModelDownloadManager(),
       _modelDownloadService = modelDownloadService ?? ModelDownloadService(),
       _storageService = storageService ?? ModelSetupStorageService(),
       _hfAuthService = hfAuthService ?? HfAuthService() {
    _modelDownloadManager.initializePort(_onDownloadEvent);
  }

  final ModelFileService _modelFileService;
  final ModelDownloadManager _modelDownloadManager;
  final ModelDownloadService _modelDownloadService;
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
  bool get canCancel => _taskId != null;

  Future<void> initialize() async {
    _state = ModelDownloadState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final exists = await _modelFileService.modelExists();
      if (exists) {
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
            case DownloadTaskStatus.complete:
              _state = ModelDownloadState.ready;
              await _storageService.markCompleted(true);
              await _storageService.clearTaskId();
              _taskId = null;
              notifyListeners();
              return;
            case DownloadTaskStatus.failed:
            case DownloadTaskStatus.paused:
            case DownloadTaskStatus.canceled:
            case DownloadTaskStatus.undefined:
              await _cleanupBrokenDownloadState();
              break;
          }
        } else {
          await _cleanupBrokenDownloadState();
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

    if (_taskId != null) {
      await _cleanupBrokenDownloadState();
    }

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      final tokenStatus = await _modelDownloadService.checkAccess(_accessToken);
      if (tokenStatus == 200) {
        await _startDownload();
        return;
      }
      if (tokenStatus == 401 || tokenStatus == 403) {
        _state = ModelDownloadState.awaitingLicenseAcceptance;
        notifyListeners();
        return;
      }
    }

    final publicStatus = await _modelDownloadService.checkAccess();
    if (publicStatus == 200) {
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

    final status = await _modelDownloadService.checkAccess(_accessToken);
    if (status == 200) {
      await _startDownload();
      return;
    }

    if (status == 401 || status == 403) {
      _state = ModelDownloadState.awaitingLicenseAcceptance;
      notifyListeners();
      return;
    }

    _state = ModelDownloadState.error;
    _errorMessage = 'Authenticated, but the model is still not accessible.';
    notifyListeners();
  }

  Future<void> retryAfterLicenseAcceptance() async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      await authenticateAndDownload();
      return;
    }

    final status = await _modelDownloadService.checkAccess(_accessToken);
    if (status == 200) {
      await _startDownload();
      return;
    }

    _state = ModelDownloadState.awaitingLicenseAcceptance;
    _errorMessage = 'License not accepted yet, or model access is still blocked.';
    notifyListeners();
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

  Future<void> cancelDownload() async {
    if (_taskId != null) {
      await _modelDownloadManager.cancelDownload(_taskId!);
    }
    await _cleanupBrokenDownloadState();

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

  Future<void> _cleanupBrokenDownloadState() async {
    await _storageService.reset();
    await _modelFileService.deleteModelIfExists();
    _taskId = null;
    _progress = 0;
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
        await _cleanupBrokenDownloadState();
        _state = ModelDownloadState.error;
        _errorMessage = 'Download failed. Please start again.';
        break;
      case DownloadTaskStatus.paused:
        await _cleanupBrokenDownloadState();
        _state = ModelDownloadState.error;
        _errorMessage = 'Download was interrupted. Please start again.';
        break;
      case DownloadTaskStatus.canceled:
        await _cleanupBrokenDownloadState();
        _state = ModelDownloadState.needsDownload;
        break;
      case DownloadTaskStatus.undefined:
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
