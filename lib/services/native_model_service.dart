import 'package:flutter/services.dart';

import '../models/model_request.dart';
import '../models/model_result.dart';
import '../models/model_status.dart';
import 'model_file_service.dart';
import 'model_service.dart';

class NativeModelService implements ModelService {
  NativeModelService({
    ModelFileService? modelFileService,
  }) : _modelFileService = modelFileService ?? ModelFileService();

  static const MethodChannel _channel = MethodChannel('lilly/model');

  final ModelFileService _modelFileService;

  ModelStatus _status = ModelStatus.uninitialized;
  String? _lastErrorMessage;

  String? get lastErrorMessage => _lastErrorMessage;

  @override
  Future<void> initialize() async {
    if (_status == ModelStatus.ready) return;

    final hasValidModel = await _modelFileService.hasValidModelFile(
      strict: true,
    );
    if (!hasValidModel) {
      _status = ModelStatus.uninitialized;
      _lastErrorMessage =
          'Model file is missing, incomplete, or corrupted. Download it again.';
      throw Exception(_lastErrorMessage);
    }

    _status = ModelStatus.loading;
    _lastErrorMessage = null;

    final modelPath = await _modelFileService.getModelPath();

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'initializeModel',
        {'modelPath': modelPath},
      );

      final success = result?['success'] == true;
      final statusString = result?['status'] as String?;
      _status = _mapStatus(statusString);
      _lastErrorMessage = result?['errorMessage'] as String?;

      if (!success || _status != ModelStatus.ready) {
        throw Exception(
          _lastErrorMessage ?? 'Native model initialization failed.',
        );
      }
    } catch (e) {
      _status = ModelStatus.error;
      if (_lastErrorMessage == null || _lastErrorMessage!.isEmpty) {
        _lastErrorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disposeModel');
    } catch (_) {}
    _status = ModelStatus.uninitialized;
  }

  @override
  Future<ModelStatus> getStatus() async {
    final hasValidModel = await _modelFileService.hasValidModelFile(
      strict: true,
    );
    if (!hasValidModel) {
      _status = ModelStatus.uninitialized;
      return _status;
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getModelStatus',
      );

      _status = _mapStatus(result?['status'] as String?);
      _lastErrorMessage = result?['errorMessage'] as String?;
      return _status;
    } catch (_) {
      return _status;
    }
  }

  @override
  Future<ModelResult> generateResponse(ModelRequest request) async {
    if (_status != ModelStatus.ready) {
      return const ModelResult.failure(
        errorMessage: 'Model is not ready yet.',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'generateResponse',
        {
          'prompt': request.prompt,
          'imagePath': request.imagePath,
          'history': request.history.map((message) => message.toMap()).toList(),
        },
      );

      if (result == null) {
        return const ModelResult.failure(
          errorMessage: 'No response returned by native model.',
        );
      }

      final success = result['success'] == true;
      final text = (result['text'] as String?) ?? '';
      final errorMessage = result['errorMessage'] as String?;

      if (!success) {
        _lastErrorMessage = errorMessage;
        return ModelResult.failure(
          errorMessage: errorMessage ?? 'Native model failed to respond.',
        );
      }

      return ModelResult.success(text: text);
    } catch (e) {
      _lastErrorMessage = e.toString().replaceFirst('Exception: ', '');
      return ModelResult.failure(
        errorMessage: _lastErrorMessage ?? 'Native model invocation failed.',
      );
    }
  }

  ModelStatus _mapStatus(String? value) {
    switch (value) {
      case 'loading':
        return ModelStatus.loading;
      case 'ready':
        return ModelStatus.ready;
      case 'error':
        return ModelStatus.error;
      case 'uninitialized':
      default:
        return ModelStatus.uninitialized;
    }
  }
}
