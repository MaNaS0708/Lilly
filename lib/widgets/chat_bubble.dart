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

    const userColor = Color(0xFFC88298);
    const assistantColor = Colors.white;
    const ink = Color(0xFF473241);
    const stroke = Color(0xFFE9CAD4);

    final bubbleColor = message.isUser ? userColor : assistantColor;
    final textColor = message.isUser ? Colors.white : ink;
    final timestampColor = message.isUser
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF7B6A74);
    final actionColor = message.isUser
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF7B6A74);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(13),
          constraints: const BoxConstraints(maxWidth: 330),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(message.isUser ? 22 : 8),
              bottomRight: Radius.circular(message.isUser ? 8 : 22),
            ),
            border: message.isUser ? null : Border.all(color: stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
                    borderRadius: BorderRadius.circular(14),
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
                    fontSize: 15.5,
                    height: 1.48,
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
