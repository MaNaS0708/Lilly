import 'package:shared_preferences/shared_preferences.dart';

class ModelSetupStorageService {
  static const _downloadTaskIdKey = 'model_download_task_id';
  static const _downloadCompletedKey = 'model_download_completed';

  Future<void> saveTaskId(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadTaskIdKey, taskId);
  }

  Future<String?> loadTaskId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadTaskIdKey);
  }

  Future<void> clearTaskId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadTaskIdKey);
  }

  Future<void> markCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_downloadCompletedKey, value);
  }

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_downloadCompletedKey) ?? false;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadTaskIdKey);
    await prefs.remove(_downloadCompletedKey);
  }
}
