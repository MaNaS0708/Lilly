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
  String _phaseLabel = 'Preparing setup';

  ModelDownloadState get state => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String get phaseLabel => _phaseLabel;
  bool get canCancel =>
      _state == ModelDownloadState.downloading && _taskId != null;

  Future<void> initialize() async {
    _state = ModelDownloadState.checking;
    _errorMessage = null;
    _phaseLabel = 'Checking local models';
    notifyListeners();

    try {
      final gemmaInfo = await _modelFileService.inspectModelFile(strict: true);
      final voskInfo = await _modelFileService.inspectVoskModel();

      if (gemmaInfo.isValid && voskInfo.isValid) {
        _state = ModelDownloadState.ready;
        _phaseLabel = 'Models ready';
        notifyListeners();
        return;
      }

      if (gemmaInfo.exists && !gemmaInfo.isValid) {
        await _modelFileService.deleteModelIfExists();
      }
      if (voskInfo.exists && !voskInfo.isValid) {
        await _modelFileService.deleteVoskIfExists();
      }

      _taskId = await _storageService.loadTaskId();
      final storedToken = await _hfAuthService.getStoredToken();
      _accessToken = storedToken?.accessToken;

      if (_taskId != null) {
        final snapshot = await _modelDownloadManager.findTask(_taskId!);
        if (snapshot != null) {
          _progress = snapshot.progress / 100.0 * 0.9;

          switch (snapshot.status) {
            case DownloadTaskStatus.running:
            case DownloadTaskStatus.enqueued:
              _state = ModelDownloadState.downloading;
              _phaseLabel = 'Downloading Gemma model';
              notifyListeners();
              return;
            case DownloadTaskStatus.complete:
              final gemmaValid = await _modelFileService.hasValidModelFile(
                strict: true,
              );
              final voskValid = await _modelFileService.hasValidVoskModel();
              if (gemmaValid && voskValid) {
                _state = ModelDownloadState.ready;
                _phaseLabel = 'Models ready';
                await _storageService.markCompleted(true);
                await _storageService.clearTaskId();
                _taskId = null;
                notifyListeners();
                return;
              }

              await _cleanupBrokenDownloadState();
              _state = ModelDownloadState.error;
              _errorMessage =
                  'Downloaded models are incomplete or corrupted. Please start again.';
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
      _phaseLabel = 'Setup required';
      notifyListeners();
    } catch (e) {
      _state = ModelDownloadState.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _phaseLabel = 'Setup failed';
      notifyListeners();
    }
  }

  Future<void> startSetup() async {
    _errorMessage = null;
    notifyListeners();

    final allValid = await _modelFileService.hasAllRuntimeModels();
    if (allValid) {
      _state = ModelDownloadState.ready;
      _phaseLabel = 'Models ready';
      notifyListeners();
      return;
    }

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
        _phaseLabel = 'License acceptance needed';
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
    _phaseLabel = 'Authenticating with Hugging Face';
    _errorMessage = null;
    notifyListeners();

    final auth = await _hfAuthService.authenticate();

    if (!auth.success || auth.tokenData == null) {
      _state = ModelDownloadState.error;
      _phaseLabel = 'Authentication failed';
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
      _phaseLabel = 'License acceptance needed';
      notifyListeners();
      return;
    }

    _state = ModelDownloadState.error;
    _phaseLabel = 'Authentication failed';
    _errorMessage = 'Authenticated, but the Gemma model is still not accessible.';
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
    _phaseLabel = 'License acceptance needed';
    _errorMessage = 'License not accepted yet, or model access is still blocked.';
    notifyListeners();
  }

  Future<void> cancelDownload() async {
    if (_taskId != null) {
      await _modelDownloadManager.cancelDownload(_taskId!);
    }
    await _cleanupBrokenDownloadState();

    _state = ModelDownloadState.needsDownload;
    _phaseLabel = 'Setup required';
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> openLicensePage() async {
    await launchUrl(
      Uri.parse(ModelSetupConstants.modelCardUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _startDownload() async {
    await _cleanupBrokenDownloadState(removeTask: false);

    _state = ModelDownloadState.downloading;
    _progress = 0;
    _errorMessage = null;
    _phaseLabel = 'Downloading Gemma model';
    notifyListeners();

    final taskId = await _modelDownloadManager.startDownload(
      accessToken: _accessToken,
    );

    if (taskId == null) {
      _state = ModelDownloadState.error;
      _phaseLabel = 'Gemma download failed';
      _errorMessage = 'Failed to start Gemma model download.';
      notifyListeners();
      return;
    }

    _taskId = taskId;
    await _storageService.saveTaskId(taskId);
  }

  Future<void> _downloadVoskAfterGemma() async {
    _state = ModelDownloadState.downloading;
    _phaseLabel = 'Downloading voice model';
    _errorMessage = null;
    _progress = 0.9;
    notifyListeners();

    try {
      await _modelDownloadService.downloadVoskModel(
        onProgress: (value) {
          _progress = 0.9 + (value * 0.1);
          notifyListeners();
        },
      );

      final gemmaValid = await _modelFileService.hasValidModelFile(strict: true);
      final voskValid = await _modelFileService.hasValidVoskModel();

      if (!gemmaValid || !voskValid) {
        throw Exception(
          'One or more models failed validation after download.',
        );
      }

      _state = ModelDownloadState.ready;
      _phaseLabel = 'Models ready';
      _progress = 1;
      await _storageService.markCompleted(true);
      await _storageService.clearTaskId();
      _taskId = null;
      notifyListeners();
    } catch (e) {
      await _cleanupBrokenDownloadState();
      _state = ModelDownloadState.error;
      _phaseLabel = 'Voice model setup failed';
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> _cleanupBrokenDownloadState({bool removeTask = true}) async {
    final currentTaskId = _taskId;
    if (removeTask && currentTaskId != null) {
      await _modelDownloadManager.removeTask(
        currentTaskId,
        shouldDeleteContent: true,
      );
    }

    await _storageService.reset();
    await _modelFileService.deleteModelIfExists();
    await _modelFileService.deleteVoskIfExists();
    _taskId = null;
    _progress = 0;
  }

  void _onDownloadEvent(String id, DownloadTaskStatus status, int progress) async {
    if (_taskId != id) return;

    _progress = progress / 100.0 * 0.9;

    switch (status) {
      case DownloadTaskStatus.running:
      case DownloadTaskStatus.enqueued:
        _state = ModelDownloadState.downloading;
        _phaseLabel = 'Downloading Gemma model';
        break;
      case DownloadTaskStatus.complete:
        final gemmaValid = await _modelFileService.hasValidModelFile(strict: true);
        if (!gemmaValid) {
          await _cleanupBrokenDownloadState();
          _state = ModelDownloadState.error;
          _phaseLabel = 'Gemma validation failed';
          _errorMessage =
              'Gemma download completed, but the model file is invalid.';
          notifyListeners();
          return;
        }
        await _downloadVoskAfterGemma();
        return;
      case DownloadTaskStatus.failed:
        await _cleanupBrokenDownloadState();
        _state = ModelDownloadState.error;
        _phaseLabel = 'Gemma download failed';
        _errorMessage = 'Gemma download failed. Please start again.';
        break;
      case DownloadTaskStatus.paused:
        await _cleanupBrokenDownloadState();
        _state = ModelDownloadState.error;
        _phaseLabel = 'Gemma download interrupted';
        _errorMessage = 'Gemma download was interrupted. Please start again.';
        break;
      case DownloadTaskStatus.canceled:
        await _cleanupBrokenDownloadState();
        _state = ModelDownloadState.needsDownload;
        _phaseLabel = 'Setup required';
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
