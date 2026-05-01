import 'package:flutter/material.dart';

import '../models/model_request.dart';
import '../models/model_result.dart';
import '../models/model_status.dart';
import '../services/model_service.dart';
import '../services/native_model_service.dart';

class ModelController extends ChangeNotifier {
  ModelController({ModelService? modelService})
    : _modelService = modelService ?? NativeModelService();

  final ModelService _modelService;

  ModelStatus _status = ModelStatus.uninitialized;
  String? _errorMessage;
  bool _isGenerating = false;

  ModelStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isGenerating => _isGenerating;

  bool get isReady => _status == ModelStatus.ready;
  bool get hasError => _status == ModelStatus.error;
  bool get isLoading => _status == ModelStatus.loading;

  Future<void>? _initFuture;

  Future<void> initialize() async {
    if (_status == ModelStatus.ready) return;

    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _errorMessage = null;
    _status = ModelStatus.loading;
    notifyListeners();

    _initFuture = _doInitialize();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInitialize() async {
    try {
      await _modelService.initialize();
      _status = await _modelService.getStatus();

      if (_status == ModelStatus.error) {
        _errorMessage = 'Failed to initialize local model.';
      }
    } catch (e) {
      _status = ModelStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    notifyListeners();
  }

  Future<bool> ensureReady() async {
    if (isReady) return true;
    await initialize();
    return isReady;
  }

  Future<ModelResult> generateResponse(
    ModelRequest request, {
    void Function(String text)? onPartialText,
    bool suppressError = false,
  }) async {
    _isGenerating = true;
    if (!suppressError) {
      _errorMessage = null;
    }
    notifyListeners();

    try {
      final result = await _modelService.generateResponse(
        request,
        onPartialText: onPartialText,
      );

      if (!result.success && !suppressError) {
        _errorMessage = result.errorMessage;
      }

      return result;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!suppressError) {
        _errorMessage = message;
      }
      return ModelResult.failure(
        errorMessage: message,
      );
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }


  Future<void> refreshStatus() async {
    try {
      _status = await _modelService.getStatus();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> shutdown() async {
    await _modelService.dispose();
    _status = ModelStatus.uninitialized;
    notifyListeners();
  }

  Future<void> releaseModelMemory() async {
    // Dispose the model to free memory when app pauses
    await _modelService.dispose();
    _status = ModelStatus.uninitialized;
    notifyListeners();
  }

  Future<void> reinitializeIfNeeded() async {
    // Reinitialize the model if needed when app resumes
    if (_status == ModelStatus.uninitialized) {
      await initialize();
    }
  }
}
