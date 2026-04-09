import '../models/model_request.dart';
import '../models/model_result.dart';
import '../models/model_status.dart';

abstract class ModelService {
  Future<void> initialize();
  Future<void> dispose();

  Future<ModelStatus> getStatus();
  Future<ModelResult> generateResponse(ModelRequest request);
}
