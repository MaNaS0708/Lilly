import 'package:shared_preferences/shared_preferences.dart';

import '../models/voice_language.dart';

class SettingsService {
  static const saveChatsKey = 'settings_save_chats';
  static const enableImagesKey = 'settings_enable_images';
  static const showDebugKey = 'settings_show_debug';
  static const triggerEnabledKey = 'settings_trigger_enabled';
  static const voiceLanguagesKey = 'settings_voice_languages';

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

  Future<List<String>> getVoiceLanguageCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(voiceLanguagesKey) ?? const [];
    final valid = stored
        .where((code) => VoiceLanguage.values.any((item) => item.code == code))
        .toList();

    if (valid.isEmpty) {
      return const <String>[];
    }

    return <String>[valid.first];
  }

  Future<String> getPrimaryVoiceLanguageCode() async {
    final stored = await getVoiceLanguageCodes();
    return stored.isEmpty ? VoiceLanguage.english.code : stored.first;
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

  Future<void> setVoiceLanguageCodes(List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = values
        .where((code) => VoiceLanguage.values.any((item) => item.code == code))
        .toList();

    final selected = valid.isEmpty ? VoiceLanguage.english.code : valid.first;
    await prefs.setStringList(voiceLanguagesKey, <String>[selected]);
  }

  Future<void> setPrimaryVoiceLanguageCode(String value) async {
    await setVoiceLanguageCodes(<String>[value]);
  }
}
