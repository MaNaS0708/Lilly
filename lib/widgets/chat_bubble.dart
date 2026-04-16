import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../screens/image_preview_screen.dart';
import 'message_timestamp.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
  });

  final ChatMessage message;

  void _openPreview(BuildContext context) {
    if (!message.hasImage) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(imagePath: message.imagePath!),
      ),
    );
  }

  Future<void> _copyMessage(BuildContext context) async {
    if (!message.hasText) return;

    await Clipboard.setData(ClipboardData(text: message.text));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final bubbleColor = message.isUser
        ? Theme.of(context).colorScheme.primary
        : Colors.white;

    final textColor = message.isUser ? Colors.white : Colors.black87;
    final timestampColor = message.isUser ? Colors.white70 : Colors.black54;
    final actionColor = message.isUser ? Colors.white70 : Colors.black54;

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
            border: message.isUser ? null : Border.all(color: Colors.black12),
            boxShadow: message.isUser
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.hasImage) ...[
                GestureDetector(
                  onTap: () => _openPreview(context),
                  child: ClipRRect(
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
                ),
                if (message.hasText) const SizedBox(height: 10),
              ],
              if (message.hasText)
                SelectableText(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MessageTimestamp(
                    timestamp: message.createdAt,
                    color: timestampColor,
                  ),
                  if (message.hasText) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _copyMessage(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      color: actionColor,
                      tooltip: 'Copy message',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
