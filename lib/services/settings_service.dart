import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const saveChatsKey = 'settings_save_chats';
  static const enableImagesKey = 'settings_enable_images';
  static const showDebugKey = 'settings_show_debug';

  Future<bool> getSaveChatsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(saveChatsKey) ?? true;
  }

  Future<bool> getEnableImageInput() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enableImagesKey) ?? true;
  }

  Future<bool> getShowDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(showDebugKey) ?? false;
  }

  Future<void> setSaveChatsLocally(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(saveChatsKey, value);
  }

  Future<void> setEnableImageInput(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enableImagesKey, value);
  }

  Future<void> setShowDebugInfo(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showDebugKey, value);
  }
}
