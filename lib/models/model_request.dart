import 'chat_message.dart';

class ModelRequest {
  final String prompt;
  final List<ChatMessage> history;
  final String? imagePath;
  final String? conversationId;

  const ModelRequest({
    required this.prompt,
    required this.history,
    this.imagePath,
    this.conversationId,
  });

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}
