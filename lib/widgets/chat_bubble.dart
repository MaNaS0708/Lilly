import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final bubbleColor = message.isUser
        ? Theme.of(context).colorScheme.primary
        : Colors.white;

    final textColor = message.isUser ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
            border: message.isUser
                ? null
                : Border.all(color: Colors.black12),
            boxShadow: message.isUser
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(message.imagePath!),
                    width: 220,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 220,
                        height: 180,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          size: 36,
                          color: Colors.black45,
                        ),
                      );
                    },
                  ),
                ),
                if (message.hasText) const SizedBox(height: 10),
              ],
              if (message.hasText)
                Text(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
