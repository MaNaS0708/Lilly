import 'package:shared_preferences/shared_preferences.dart';

import '../models/voice_language.dart';

class SettingsService {
  static const saveChatsKey = 'settings_save_chats';
  static const enableImagesKey = 'settings_enable_images';
  static const showDebugKey = 'settings_show_debug';
  static const triggerEnabledKey = 'settings_trigger_enabled';
  static const voiceLanguageKey = 'settings_voice_language';

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

  Future<bool> getTriggerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(triggerEnabledKey) ?? false;
  }

  Future<String?> getVoiceLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(voiceLanguageKey);
    if (stored == null) return null;

    for (final language in VoiceLanguage.values) {
      if (language.code == stored) {
        return stored;
      }
    }

    return null;
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

  Future<void> setTriggerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(triggerEnabledKey, value);
  }

  Future<void> setVoiceLanguageCode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(voiceLanguageKey, VoiceLanguage.fromCode(value).code);
  }

  Future<void> clearVoiceLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(voiceLanguageKey);
  }
}
