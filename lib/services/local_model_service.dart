import '../models/ai_response.dart';
import '../models/chat_message.dart';

class LocalModelService {
  Future<AiResponse> generateResponse({
    required String prompt,
    required List<ChatMessage> history,
    required bool hasImage,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (hasImage && prompt.isNotEmpty) {
      return const AiResponse.success(
        text:
            'Image + text received. Replace this with your real on-device vision model response.',
      );
    }

    if (hasImage) {
      return const AiResponse.success(
        text:
            'Image received. Replace this with your real on-device image analysis response.',
      );
    }

    if (prompt.trim().isEmpty) {
      return const AiResponse.failure(
        errorMessage: 'Please enter a message or attach an image.',
      );
    }

    return AiResponse.success(
      text:
          'Local model placeholder reply for: "$prompt". Replace this with your real offline model.',
    );
  }
}
