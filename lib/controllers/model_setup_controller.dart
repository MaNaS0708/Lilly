import 'package:flutter/foundation.dart';
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
  String _activeModelLabel = 'None';

  ModelDownloadState get state => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String get phaseLabel => _phaseLabel;
  String get activeModelLabel => _activeModelLabel;
  bool get canCancel =>
      _state == ModelDownloadState.downloading && _taskId != null;

  String get requiredVoiceLanguageSummary {
    if (_requiredVoiceLanguages.isEmpty) return 'None';
    return _requiredVoiceLanguages.map((item) => item.label).join(', ');
  }

  Future<void> initialize() async {
    _state = ModelDownloadState.checking;
    _errorMessage = null;
    _phaseLabel = 'Checking local models';
    _activeModelLabel = 'Checking Gemma model';
    notifyListeners();

    try {
      _requiredVoiceLanguages = await _loadRequiredVoiceLanguages();

      if (_requiredVoiceLanguages.isEmpty) {
        _state = ModelDownloadState.needsDownload;
        _phaseLabel = 'Language selection required';
        _activeModelLabel = 'No speech language selected';
        notifyListeners();
        return;
      }

      await _modelFileService.deleteLegacyVoiceAssets();

      final gemmaInfo = await _modelFileService.inspectModelFile(strict: true);
      if (gemmaInfo.isValid) {
        _completeSetup();
        notifyListeners();
        return;
      }

      await _storageService.clearTaskId();
      _taskId = null;

      final storedToken = await _hfAuthService.getStoredToken();
      _accessToken = storedToken?.accessToken;

      _state = ModelDownloadState.needsDownload;
      _phaseLabel = 'Setup required';
      _activeModelLabel = 'Gemma multilingual model';
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
      _errorMessage = 'Choose at least one speech language before setup.';
      notifyListeners();
      return;
    }

    await _modelFileService.deleteLegacyVoiceAssets();
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
      _completeSetup();
      notifyListeners();
      return;
    }

    await _modelFileService.deleteAllModelArtifacts();
    await _storageService.clearTaskId();
    _taskId = null;

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      final tokenStatus = await _modelDownloadService.checkAccess(_accessToken);
      if (tokenStatus == 200) {
        await _startGemmaDownload();
        return;
      }
      if (tokenStatus == 401 || tokenStatus == 403) {
        _state = ModelDownloadState.awaitingLicenseAcceptance;
        _phaseLabel = 'License acceptance needed';
        _activeModelLabel = 'Gemma multilingual model';
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
    _activeModelLabel = 'Gemma multilingual model';
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
      _activeModelLabel = 'Gemma multilingual model';
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
    _activeModelLabel = 'Gemma multilingual model';
    _errorMessage = 'License not accepted yet, or model access is still blocked.';
    notifyListeners();
  }

  Future<void> cancelDownload() async {
    if (_taskId != null) {
      await _modelDownloadManager.cancelDownload(_taskId!);
    } else {
      await _modelFileService.deleteAllModelArtifacts();
    }

    await _storageService.clearTaskId();
    await _storageService.markCompleted(false);
    _taskId = null;
    _progress = 0;

    _state = ModelDownloadState.needsDownload;
    _phaseLabel = 'Setup required';
    _activeModelLabel = 'Gemma multilingual model';
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
    _state = ModelDownloadState.downloading;
    _progress = 0;
    _errorMessage = null;
    _phaseLabel = 'Downloading Gemma model';
    _activeModelLabel = 'Gemma multilingual model';
    notifyListeners();

    debugPrint('[LillySetup] Starting in-app stream download for ${ModelSetupConstants.modelUrl}');

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
    debugPrint('[LillySetup] In-app download started with taskId=$taskId');
  }

  Future<List<VoiceLanguage>> _loadRequiredVoiceLanguages() async {
    final selectedCodes = await _settingsService.getVoiceLanguageCodes();
    return selectedCodes.map(VoiceLanguage.fromCode).toList();
  }

  void _completeSetup() {
    _state = ModelDownloadState.ready;
    _phaseLabel = 'Gemma ready';
    _activeModelLabel = 'Voice chat language: $requiredVoiceLanguageSummary';
    _progress = 1;
    _taskId = null;
    _storageService.markCompleted(true);
    _storageService.clearTaskId();
  }

  void _onDownloadEvent(
    String id,
    DownloadTaskStatus status,
    int progress,
  ) async {
    if (_taskId != null && _taskId != id) {
      debugPrint('[LillySetup] Ignoring event for stale task $id');
      return;
    }

    _taskId ??= id;
    _progress = progress / 100.0;

    debugPrint(
      '[LillySetup] Download event: taskId=$id status=$status progress=$progress',
    );

    switch (status) {
      case DownloadTaskStatus.running:
      case DownloadTaskStatus.enqueued:
        _state = ModelDownloadState.downloading;
        _phaseLabel = 'Downloading Gemma model';
        _activeModelLabel = ModelSetupConstants.modelFileName;
        break;

      case DownloadTaskStatus.complete:
        await _storageService.clearTaskId();
        _taskId = null;

        final gemmaValid = await _modelFileService.hasValidModelFile(strict: true);
        if (!gemmaValid) {
          _state = ModelDownloadState.error;
          _phaseLabel = 'Gemma validation failed';
          _errorMessage =
              'Gemma download completed, but the model file is invalid. Delete the model and retry.';
          notifyListeners();
          return;
        }

        _completeSetup();
        notifyListeners();
        return;

      case DownloadTaskStatus.failed:
        await _storageService.clearTaskId();
        _taskId = null;
        _state = ModelDownloadState.error;
        _phaseLabel = 'Gemma download failed';
        _errorMessage =
            'Gemma download failed during in-app streaming. Check logcat for [LillySetup].';
        break;

      case DownloadTaskStatus.paused:
        _state = ModelDownloadState.error;
        _phaseLabel = 'Gemma download paused';
        _errorMessage = 'Gemma download paused unexpectedly.';
        break;

      case DownloadTaskStatus.canceled:
        await _storageService.clearTaskId();
        _taskId = null;
        _state = ModelDownloadState.needsDownload;
        _phaseLabel = 'Setup required';
        _errorMessage = 'Gemma download was canceled.';
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
