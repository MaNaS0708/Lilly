import '../models/chat_conversation.dart';

class ChatStorageService {
  Future<void> saveConversation(ChatConversation conversation) async {
    // Placeholder for SharedPreferences, Hive, Isar, or SQLite.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<List<ChatConversation>> loadConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const [];
  }

  Future<void> clearAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
