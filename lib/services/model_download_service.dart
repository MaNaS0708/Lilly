import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/model_setup_constants.dart';
import 'model_file_service.dart';

class ModelDownloadService {
  ModelDownloadService({
    ModelFileService? modelFileService,
  }) : _modelFileService = modelFileService ?? ModelFileService();

  final ModelFileService _modelFileService;

  Future<int> checkAccess([String? accessToken]) async {
    try {
      final headers = <String, String>{};
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      print('Checking model access: ${ModelSetupConstants.modelUrl}');
      print(
        'Access token present: ${accessToken != null && accessToken.isNotEmpty}',
      );

      final response = await http.head(
        Uri.parse(ModelSetupConstants.modelUrl),
        headers: headers,
      );

      print('Access response status: ${response.statusCode}');
      return response.statusCode;
    } catch (e) {
      print('Access check failed: $e');
      return -1;
    }
  }

  Future<void> downloadModel({
    required void Function(double progress) onProgress,
    String? accessToken,
  }) async {
    final file = await _modelFileService.getModelFile();

    final headers = <String, String>{};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    IOSink? sink;

    try {
      print('Starting model download...');
      print('Download URL: ${ModelSetupConstants.modelUrl}');
      print(
        'Auth token present: ${accessToken != null && accessToken.isNotEmpty}',
      );
      print('Saving model to: ${file.path}');

      final request = http.Request(
        'GET',
        Uri.parse(ModelSetupConstants.modelUrl),
      );
      request.headers.addAll(headers);

      final response = await request.send();

      print('Download response status: ${response.statusCode}');
      print('Content length: ${response.contentLength}');

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      sink = file.openWrite();

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);

        print('Received bytes: $received / $total');

        if (total > 0) {
          onProgress(received / total);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      print('Download stream finished successfully');
    } catch (e) {
      print('Download failed: $e');

      try {
        await sink?.flush();
      } catch (_) {}

      try {
        await sink?.close();
      } catch (_) {}

      try {
        if (await file.exists()) {
          await file.delete();
          print('Deleted partial model file after failure');
        }
      } catch (deleteError) {
        print('Failed to delete partial file: $deleteError');
      }

      throw Exception(
        'Model download interrupted. Please check your internet connection and try again.',
      );
    }
  }
}
