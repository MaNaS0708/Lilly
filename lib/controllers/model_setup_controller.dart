import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/model_download_state.dart';
import '../services/hf_auth_service.dart';
import '../services/model_download_service.dart';
import '../services/model_file_service.dart';

class ModelSetupController extends ChangeNotifier {
  ModelSetupController({
    ModelFileService? modelFileService,
    ModelDownloadService? modelDownloadService,
    HfAuthService? hfAuthService,
  }) : _modelFileService = modelFileService ?? ModelFileService(),
       _modelDownloadService = modelDownloadService ?? ModelDownloadService(),
       _hfAuthService = hfAuthService ?? HfAuthService();

  final ModelFileService _modelFileService;
  final ModelDownloadService _modelDownloadService;
  final HfAuthService _hfAuthService;

  ModelDownloadState _state = ModelDownloadState.checking;
  double _progress = 0;
  String? _errorMessage;
  String? _accessToken;

  ModelDownloadState get state => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;

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

      _state = ModelDownloadState.needsDownload;
      notifyListeners();

      await _beginDownloadFlow();
    } catch (e) {
      _state = ModelDownloadState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _beginDownloadFlow() async {
    final accessCode = await _modelDownloadService.checkAccess();

    if (accessCode == 200) {
      await _download();
      return;
    }

    if (accessCode == 403 || accessCode == 401) {
      await authenticateAndDownload();
      return;
    }

    throw Exception('Unable to access model. Status: $accessCode');
  }

  Future<void> authenticateAndDownload() async {
    _state = ModelDownloadState.authenticating;
    _errorMessage = null;
    notifyListeners();

    final auth = await _hfAuthService.authenticate();

    if (!auth.success) {
      _state = ModelDownloadState.error;
      _errorMessage = auth.error ?? 'Authentication failed.';
      notifyListeners();
      return;
    }

    _accessToken = auth.accessToken;

    final status = await _modelDownloadService.checkAccess(_accessToken);
    if (status == 200) {
      await _download();
      return;
    }

    if (status == 403) {
      _state = ModelDownloadState.awaitingLicenseAcceptance;
      notifyListeners();
      return;
    }

    _state = ModelDownloadState.error;
    _errorMessage = 'Authenticated, but model access still failed.';
    notifyListeners();
  }

  Future<void> openLicensePage() async {
    final uri = Uri.parse('https://huggingface.co/YOUR_MODEL_PATH');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> retryAfterLicenseAcceptance() async {
    if (_accessToken == null) {
      await authenticateAndDownload();
      return;
    }

    final status = await _modelDownloadService.checkAccess(_accessToken);
    if (status == 200) {
      await _download();
      return;
    }

    _state = ModelDownloadState.error;
    _errorMessage = 'License still not accepted or model still unavailable.';
    notifyListeners();
  }

  Future<void> _download() async {
    _state = ModelDownloadState.downloading;
    _progress = 0;
    _errorMessage = null;
    notifyListeners();

    await _modelDownloadService.downloadModel(
      accessToken: _accessToken,
      onProgress: (value) {
        _progress = value;
        notifyListeners();
      },
    );

    _state = ModelDownloadState.ready;
    notifyListeners();
  }
}
