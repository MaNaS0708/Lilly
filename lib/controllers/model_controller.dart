import 'package:flutter/material.dart';

import '../models/model_request.dart';
import '../models/model_result.dart';
import '../models/model_status.dart';
import '../services/model_service.dart';
import '../services/native_model_service.dart';

class ModelController extends ChangeNotifier {
  ModelController({
    ModelService? modelService,
  }) : _modelService = modelService ?? NativeModelService();

  final ModelService _modelService;

  ModelStatus _status = ModelStatus.uninitialized;
  String? _errorMessage;
  bool _isGenerating = false;

  ModelStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isGenerating => _isGenerating;

  bool get isReady => _status == ModelStatus.ready;
  bool get hasError => _status == ModelStatus.error;

  Future<void> initialize() async {
    _errorMessage = null;
    _status = ModelStatus.loading;
    notifyListeners();

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

  Future<ModelResult> generateResponse(ModelRequest request) async {
    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _modelService.generateResponse(request);

      if (!result.success) {
        _errorMessage = result.errorMessage;
      }

      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return ModelResult.failure(
        errorMessage: _errorMessage ?? 'Failed to generate response.',
      );
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    _status = await _modelService.getStatus();
    notifyListeners();
  }

  Future<void> shutdown() async {
    await _modelService.dispose();
    _status = ModelStatus.uninitialized;
    notifyListeners();
  }
}
