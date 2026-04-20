import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/model_setup_constants.dart';
import '../models/model_download_state.dart';
import '../models/voice_language.dart';
import '../services/hf_auth_service.dart';
import '../services/model_download_manager.dart';
import '../services/model_download_service.dart';
import '../services/model_file_service.dart';
import '../services/model_setup_storage_service.dart';
import '../services/settings_service.dart';

class ModelSetupController extends ChangeNotifier {
  ModelSetupController({
    ModelFileService? modelFileService,
    ModelDownloadManager? modelDownloadManager,
    ModelDownloadService? modelDownloadService,
    ModelSetupStorageService? storageService,
    HfAuthService? hfAuthService,
    SettingsService? settingsService,
  }) : _modelFileService = modelFileService ?? ModelFileService(),
       _modelDownloadManager = modelDownloadManager ?? ModelDownloadManager(),
       _modelDownloadService = modelDownloadService ?? ModelDownloadService(),
       _storageService = storageService ?? ModelSetupStorageService(),
       _hfAuthService = hfAuthService ?? HfAuthService(),
       _settingsService = settingsService ?? SettingsService() {
    _modelDownloadManager.initializePort(_onDownloadEvent);
  }

  final ModelFileService _modelFileService;
  final ModelDownloadManager _modelDownloadManager;
  final ModelDownloadService _modelDownloadService;
  final ModelSetupStorageService _storageService;
  final HfAuthService _hfAuthService;
  final SettingsService _settingsService;

  ModelDownloadState _state = ModelDownloadState.checking;
  double _progress = 0;
  String? _errorMessage;
  String? _accessToken;
  String? _taskId;
  String _phaseLabel = 'Preparing setup';
  List<VoiceLanguage> _requiredVoiceLanguages = const [];

  ModelDownloadState get state => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String get phaseLabel => _phaseLabel;
  bool get canCancel =>
      _state == ModelDownloadState.downloading && _taskId != null;

  String get requiredVoiceLanguageSummary {
    if (_requiredVoiceLanguages.isEmpty) {
      return 'voice language';
    }
    return _requiredVoiceLanguages.map((language) => language.label).join(', ');
  }

  Future<void> initialize() async {
    _state = ModelDownloadState.checking;
    _errorMessage = null;
    _phaseLabel = 'Checking local models';
    notifyListeners();

    try {
      _requiredVoiceLanguages = await _loadRequiredVoiceLanguages();

      if (_requiredVoiceLanguages.isEmpty) {
        _state = ModelDownloadState.needsDownload;
        _phaseLabel = 'Language selection required';
        notifyListeners();
        return;
      }

      await _modelFileService.deleteUnusedVoiceModels(
        _requiredVoiceLanguages.map((item) => item.code),
      );

      final gemmaInfo = await _modelFileService.inspectModelFile(strict: true);
      final voiceModelsReady = await _areRequiredVoiceModelsReady();

      if (gemmaInfo.isValid && voiceModelsReady) {
        _completeSetup();
        notifyListeners();
        return;
      }

      if (gemmaInfo.exists && !gemmaInfo.isValid) {
        await _modelFileService.deleteModelIfExists();
      }
      await _deleteInvalidVoiceModels();

      _taskId = await _storageService.loadTaskId();
      final storedToken = await _hfAuthService.getStoredToken();
      _accessToken = storedToken?.accessToken;

      if (_taskId != null) {
        final snapshot = await _modelDownloadManager.findTask(_taskId!);
        if (snapshot != null) {
          _progress = snapshot.progress / 100.0 * 0.75;

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
              await _storageService.clearTaskId();
              _taskId = null;

              if (gemmaValid) {
                _state = ModelDownloadState.needsDownload;
                _phaseLabel = 'Voice model download required';
                notifyListeners();
                return;
              }

              await _cleanupGemmaDownloadState(removeTask: false);
              _state = ModelDownloadState.error;
              _errorMessage =
                  'Gemma download completed, but the model file is invalid. Please start again.';
              notifyListeners();
              return;
            case DownloadTaskStatus.failed:
            case DownloadTaskStatus.paused:
            case DownloadTaskStatus.canceled:
            case DownloadTaskStatus.undefined:
              await _cleanupGemmaDownloadState();
              break;
          }
        } else {
          await _cleanupGemmaDownloadState(removeTask: false);
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
    _requiredVoiceLanguages = await _loadRequiredVoiceLanguages();

    if (_requiredVoiceLanguages.isEmpty) {
      _state = ModelDownloadState.error;
      _phaseLabel = 'Language selection required';
      _errorMessage = 'Choose a voice language before starting setup.';
      notifyListeners();
      return;
    }

    await _modelFileService.deleteUnusedVoiceModels(
      _requiredVoiceLanguages.map((item) => item.code),
    );
    notifyListeners();

    final allValid = await _modelFileService.hasAllRuntimeModels(
      voiceLanguageCodes: _requiredVoiceLanguages.map((item) => item.code),
    );
    if (allValid) {
      _completeSetup();
      notifyListeners();
      return;
    }

    final gemmaValid = await _modelFileService.hasValidModelFile(strict: true);
    if (gemmaValid) {
      await _downloadRequiredVoiceModels(gemmaAlreadyReady: true);
      return;
    }

    if (_taskId != null) {
      await _cleanupGemmaDownloadState();
    }

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      final tokenStatus = await _modelDownloadService.checkAccess(_accessToken);
      if (tokenStatus == 200) {
        await _startGemmaDownload();
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
      await _startGemmaDownload();
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
      await _startGemmaDownload();
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
      await _startGemmaDownload();
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
      await _cleanupGemmaDownloadState(removeTask: false);
    }

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

  Future<void> _startGemmaDownload() async {
    await _cleanupGemmaDownloadState(removeTask: false);

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

  Future<void> _downloadRequiredVoiceModels({
    required bool gemmaAlreadyReady,
  }) async {
    final missing = await _missingVoiceLanguages();
    if (missing.isEmpty) {
      _completeSetup();
      notifyListeners();
      return;
    }

    final progressStart = gemmaAlreadyReady ? 0.0 : 0.75;
    final progressSpan = gemmaAlreadyReady ? 1.0 : 0.25;

    _state = ModelDownloadState.downloading;
    _errorMessage = null;
    _progress = progressStart;
    notifyListeners();

    try {
      for (var index = 0; index < missing.length; index++) {
        final language = missing[index];
        _phaseLabel = 'Downloading ${language.label} voice model';
        notifyListeners();

        await _modelDownloadService.downloadVoskModel(
          language: language,
          onProgress: (value) {
            _progress =
                progressStart +
                (((index + value) / missing.length) * progressSpan);
            notifyListeners();
          },
        );
      }

      final gemmaValid = await _modelFileService.hasValidModelFile(strict: true);
      final voicesReady = await _areRequiredVoiceModelsReady();

      if (!gemmaValid || !voicesReady) {
        throw Exception('One or more runtime models failed validation after download.');
      }

      _completeSetup();
      notifyListeners();
    } catch (e) {
      _state = ModelDownloadState.error;
      _phaseLabel = 'Voice model setup failed';
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<List<VoiceLanguage>> _loadRequiredVoiceLanguages() async {
    final selectedCode = await _settingsService.getVoiceLanguageCode();
    if (selectedCode == null) return const [];
    return [VoiceLanguage.fromCode(selectedCode)];
  }

  Future<bool> _areRequiredVoiceModelsReady() async {
    for (final language in _requiredVoiceLanguages) {
      if (!await _modelFileService.hasValidVoskModel(language.code)) {
        return false;
      }
    }
    return true;
  }

  Future<List<VoiceLanguage>> _missingVoiceLanguages() async {
    final missing = <VoiceLanguage>[];
    for (final language in _requiredVoiceLanguages) {
      final valid = await _modelFileService.hasValidVoskModel(language.code);
      if (!valid) {
        missing.add(language);
      }
    }
    return missing;
  }

  Future<void> _deleteInvalidVoiceModels() async {
    for (final language in _requiredVoiceLanguages) {
      final exists = await _modelFileService.voskModelExists(language.code);
      final valid = await _modelFileService.hasValidVoskModel(language.code);
      if (exists && !valid) {
        await _modelFileService.deleteVoskIfExists(language.code);
      }
    }
  }

  Future<void> _cleanupGemmaDownloadState({bool removeTask = true}) async {
    final currentTaskId = _taskId;
    if (removeTask && currentTaskId != null) {
      await _modelDownloadManager.removeTask(
        currentTaskId,
        shouldDeleteContent: true,
      );
    }

    await _storageService.clearTaskId();
    _taskId = null;
    _progress = 0;
    await _modelFileService.deleteModelIfExists();
  }

  void _completeSetup() {
    _state = ModelDownloadState.ready;
    _phaseLabel = 'Models ready';
    _progress = 1;
    _taskId = null;
    _storageService.markCompleted(true);
    _storageService.clearTaskId();
  }

  void _onDownloadEvent(String id, DownloadTaskStatus status, int progress) async {
    if (_taskId != id) return;

    _progress = progress / 100.0 * 0.75;

    switch (status) {
      case DownloadTaskStatus.running:
      case DownloadTaskStatus.enqueued:
        _state = ModelDownloadState.downloading;
        _phaseLabel = 'Downloading Gemma model';
        break;
      case DownloadTaskStatus.complete:
        final gemmaValid = await _modelFileService.hasValidModelFile(strict: true);
        await _storageService.clearTaskId();
        _taskId = null;

        if (!gemmaValid) {
          await _cleanupGemmaDownloadState(removeTask: false);
          _state = ModelDownloadState.error;
          _phaseLabel = 'Gemma validation failed';
          _errorMessage =
              'Gemma download completed, but the model file is invalid.';
          notifyListeners();
          return;
        }

        await _downloadRequiredVoiceModels(gemmaAlreadyReady: false);
        return;
      case DownloadTaskStatus.failed:
        await _cleanupGemmaDownloadState();
        _state = ModelDownloadState.error;
        _phaseLabel = 'Gemma download failed';
        _errorMessage = 'Gemma download failed. Please start again.';
        break;
      case DownloadTaskStatus.paused:
        await _cleanupGemmaDownloadState();
        _state = ModelDownloadState.error;
        _phaseLabel = 'Gemma download interrupted';
        _errorMessage = 'Gemma download was interrupted. Please start again.';
        break;
      case DownloadTaskStatus.canceled:
        await _cleanupGemmaDownloadState(removeTask: false);
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
