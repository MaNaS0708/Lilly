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

  @override
  Future<void> initialize() async {
    if (_status == ModelStatus.ready) return;

    _status = ModelStatus.loading;

    final modelPath = await _modelFileService.getModelPath();

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'initializeModel',
        {'modelPath': modelPath},
      );

      final success = result?['success'] == true;
      final statusString = result?['status'] as String?;

      _status = _mapStatus(statusString);

      if (!success || _status != ModelStatus.ready) {
        throw Exception(
          result?['errorMessage'] ?? 'Native model initialization failed.',
        );
      }
    } catch (e) {
      _status = ModelStatus.error;
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
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getModelStatus',
      );

      _status = _mapStatus(result?['status'] as String?);
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
        return ModelResult.failure(
          errorMessage: errorMessage ?? 'Native model failed to respond.',
        );
      }

      return ModelResult.success(text: text);
    } catch (_) {
      return const ModelResult.failure(
        errorMessage: 'Native model invocation failed.',
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
