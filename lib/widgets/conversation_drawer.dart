import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';

class ConversationDrawer extends StatelessWidget {
  final List<ChatConversation> conversations;
  final String? selectedConversationId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<String> onDeleteConversation;

  const ConversationDrawer({
    super.key,
    required this.conversations,
    required this.selectedConversationId,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onDeleteConversation,
  });

  String _subtitle(ChatConversation conversation) {
    if (conversation.messages.isEmpty) {
      return 'Empty chat';
    }

    final last = conversation.messages.last;
    if (last.text.trim().isNotEmpty) {
      return last.text.trim();
    }

    if (last.hasImage) {
      return 'Image message';
    }

    return 'Conversation';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.edit_square_rounded),
                  label: const Text('New Chat'),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final selected = conversation.id == selectedConversationId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE8EAF6) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: selected ? Colors.indigo : Colors.grey.shade700,
                      ),
                      title: Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _subtitle(conversation),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        onPressed: () => onDeleteConversation(conversation.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                      onTap: () => onSelectConversation(conversation.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
