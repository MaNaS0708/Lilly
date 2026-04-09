import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class ChatStorageService {
  static const String _messagesKey = 'chat_messages';

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = messages.map((message) => message.toMap()).toList();
    await prefs.setString(_messagesKey, jsonEncode(payload));
  }

  Future<List<ChatMessage>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messagesKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => ChatMessage.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
  }
}
