import 'package:http/http.dart' as http;

import '../config/model_setup_constants.dart';

class ModelDownloadService {
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
}
