import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_conversation.dart';

class ConversationStorageService {
  static const String _conversationsKey = 'chat_conversations';
  static const String _selectedConversationIdKey = 'selected_conversation_id';

  Future<List<ChatConversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_conversationsKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    final conversations = decoded
        .whereType<Map>()
        .map((item) => ChatConversation.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  Future<void> saveConversations(List<ChatConversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = conversations.map((conversation) => conversation.toMap()).toList();
    await prefs.setString(_conversationsKey, jsonEncode(payload));
  }

  Future<String?> loadSelectedConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedConversationIdKey);
  }

  Future<void> saveSelectedConversationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();

    if (id == null) {
      await prefs.remove(_selectedConversationIdKey);
      return;
    }

    await prefs.setString(_selectedConversationIdKey, id);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_conversationsKey);
    await prefs.remove(_selectedConversationIdKey);
  }
}
