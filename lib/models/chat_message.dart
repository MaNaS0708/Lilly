import 'dart:io';

class ChatMessage {
  final String text;
  final bool isUser;
  final File? imageFile;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.imageFile,
  });

  bool get hasImage => imageFile != null;
  bool get hasText => text.trim().isNotEmpty;
}
