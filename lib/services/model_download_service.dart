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

      final response = await http.head(
        Uri.parse(ModelSetupConstants.modelUrl),
        headers: headers,
      );
      return response.statusCode;
    } catch (_) {
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

    final request = http.Request('GET', Uri.parse(ModelSetupConstants.modelUrl));
    request.headers.addAll(headers);

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Download failed with status ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    var received = 0;

    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      received += chunk.length;
      sink.add(chunk);

      if (total > 0) {
        onProgress(received / total);
      }
    }

    await sink.flush();
    await sink.close();
  }
}
