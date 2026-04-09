import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import 'chat_bubble.dart';
import 'chat_loading_bubble.dart';
import 'empty_chat_state.dart';

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool isLoading;

  const MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isLoading) {
      return const EmptyChatState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return const ChatLoadingBubble();
        }

        return ChatBubble(message: messages[index]);
      },
    );
  }
}
