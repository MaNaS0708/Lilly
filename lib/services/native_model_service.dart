import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/model_request.dart';
import '../models/model_result.dart';
import '../models/model_status.dart';
import 'model_file_service.dart';
import 'model_service.dart';

class NativeModelService implements ModelService {
  NativeModelService({ModelFileService? modelFileService})
    : _modelFileService = modelFileService ?? ModelFileService();

  static const MethodChannel _channel = MethodChannel('lilly/model');
  static const EventChannel _eventChannel = EventChannel('lilly/model_stream');

  final ModelFileService _modelFileService;
  Stream<dynamic>? _modelEvents;

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
  Future<ModelResult> generateResponse(
    ModelRequest request, {
    void Function(String text)? onPartialText,
  }) async {
    if (_status != ModelStatus.ready) {
      return const ModelResult.failure(errorMessage: 'Model is not ready yet.');
    }

    if (onPartialText != null) {
      return _generateStreamingResponse(request, onPartialText: onPartialText);
    }

    return _generateBufferedResponse(request);
  }

  Future<ModelResult> _generateBufferedResponse(ModelRequest request) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'generateResponse',
        {
          'prompt': request.prompt,
          'imagePath': request.imagePath,
          'conversationId': request.conversationId,
          'history': request.history.map((message) => message.toMap()).toList(),
        },
      );

      if (result == null) {
        return const ModelResult.failure(
          errorMessage: 'No response returned by native model.',
        );
      }

      return _mapModelResult(result);
    } catch (e) {
      _lastErrorMessage = e.toString().replaceFirst('Exception: ', '');
      return ModelResult.failure(
        errorMessage: _lastErrorMessage ?? 'Native model invocation failed.',
      );
    }
  }

  Future<ModelResult> _generateStreamingResponse(
    ModelRequest request, {
    required void Function(String text) onPartialText,
  }) async {
    final requestId = 'req-${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<ModelResult>();
    final buffer = StringBuffer();
    StreamSubscription<dynamic>? subscription;
    Timer? timeoutTimer;

    void complete(ModelResult result) {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      if (!result.success) {
        _lastErrorMessage = result.errorMessage;
      }
      completer.complete(result);
      unawaited(subscription?.cancel());
    }

    void applyText(String nextText) {
      if (nextText.isEmpty) return;

      final current = buffer.toString();

      final combined = nextText.startsWith(current)
          ? nextText
          : '$current$nextText';

      if (combined == current) return;

      buffer
        ..clear()
        ..write(combined);

      onPartialText(combined.trimLeft());
    }


    _modelEvents ??= _eventChannel.receiveBroadcastStream().asBroadcastStream();
    subscription = _modelEvents!.listen(
      (event) {
        final map = event is Map ? event : null;
        if (map == null || map['requestId'] != requestId) return;

        final type = map['type'] as String?;
        final text = (map['text'] as String?) ?? '';

        switch (type) {
          case 'partial':
            applyText(text);
            break;
          case 'done':
            applyText(text);
            complete(ModelResult.success(text: buffer.toString().trim()));
            break;
          case 'error':
            complete(
              ModelResult.failure(
                errorMessage:
                    (map['errorMessage'] as String?) ??
                    'Native model failed to respond.',
              ),
            );
            break;
          case 'metrics':
            debugPrint('[LillyModel] ${map['summary']}');
            break;
        }
      },
      onError: (Object error) {
        complete(
          ModelResult.failure(
            errorMessage: error.toString().replaceFirst('Exception: ', ''),
          ),
        );
      },
    );
    timeoutTimer = Timer(const Duration(minutes: 3), () {
      complete(
        const ModelResult.failure(
          errorMessage: 'The local model took too long to respond. Try again.',
        ),
      );
    });

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'generateResponseStream',
        {
          'requestId': requestId,
          'prompt': request.prompt,
          'imagePath': request.imagePath,
          'conversationId': request.conversationId,
          'history': request.history.map((message) => message.toMap()).toList(),
        },
      );

      if (result == null) {
        complete(
          const ModelResult.failure(
            errorMessage: 'No response returned by native model.',
          ),
        );
        return completer.future;
      }

      if (result['success'] != true) {
        complete(
          ModelResult.failure(
            errorMessage:
                (result['errorMessage'] as String?) ??
                'Native model failed to respond.',
          ),
        );
        return completer.future;
      }

      return completer.future;
    } catch (e) {
      complete(
        ModelResult.failure(
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return completer.future;
    }
  }

  ModelResult _mapModelResult(Map<dynamic, dynamic> result) {
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
