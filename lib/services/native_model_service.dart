import 'package:flutter/services.dart';

import '../models/model_request.dart';
import '../models/model_result.dart';
import '../models/model_status.dart';
import 'model_service.dart';

class NativeModelService implements ModelService {
  static const MethodChannel _channel = MethodChannel('lilly/model');

  ModelStatus _status = ModelStatus.uninitialized;

  @override
  Future<void> initialize() async {
    if (_status == ModelStatus.ready) return;

    _status = ModelStatus.loading;

    try {
      final result = await _channel.invokeMethod<bool>('initializeModel');
      if (result == true) {
        _status = ModelStatus.ready;
      } else {
        _status = ModelStatus.error;
      }
    } catch (_) {
      _status = ModelStatus.error;
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
    return _status;
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
}
