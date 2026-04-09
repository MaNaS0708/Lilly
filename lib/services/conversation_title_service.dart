import '../models/chat_message.dart';

class ConversationTitleService {
  String buildTitle({
    required String currentTitle,
    required List<ChatMessage> messages,
  }) {
    if (currentTitle != 'New Chat') return currentTitle;

    for (final message in messages) {
      if (!message.isUser) continue;

      final text = message.text.trim();
      if (text.isEmpty) continue;

      return _normalize(text);
    }

    for (final message in messages) {
      if (message.hasImage) {
        return 'Image Chat';
      }
    }

    return currentTitle;
  }

  String _normalize(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length <= 36) {
      return cleaned;
    }

    return '${cleaned.substring(0, 36).trim()}...';
  }
}
