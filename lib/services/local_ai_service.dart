import '../models/chat_message.dart';

class LocalAiService {
  Future<String> generateReply({
    required String prompt,
    required List<ChatMessage> history,
    required bool hasImage,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (hasImage && prompt.isNotEmpty) {
      return 'You sent an image with the message: "$prompt". Connect your on-device vision model here.';
    }

    if (hasImage) {
      return 'You sent an image. Connect your on-device vision model here to analyze it.';
    }

    if (prompt.isEmpty) {
      return 'Your local assistant is ready for image and text input.';
    }

    return 'You said: "$prompt". Connect your local chat model here.';
  }
}
