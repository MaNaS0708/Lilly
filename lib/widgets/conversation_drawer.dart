import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';

class ConversationDrawer extends StatefulWidget {
  final List<ChatConversation> conversations;
  final String? selectedConversationId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<String> onDeleteConversation;
  final ValueChanged<String> onRenameConversation;

  const ConversationDrawer({
    super.key,
    required this.conversations,
    required this.selectedConversationId,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onDeleteConversation,
    required this.onRenameConversation,
  });

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  String _query = '';

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

  List<_ConversationGroup> _groupedConversations() {
    final now = DateTime.now();

    final filtered = widget.conversations.where((conversation) {
      if (_query.trim().isEmpty) return true;

      final q = _query.toLowerCase();
      return conversation.title.toLowerCase().contains(q) ||
          _subtitle(conversation).toLowerCase().contains(q);
    }).toList();

    final today = <ChatConversation>[];
    final yesterday = <ChatConversation>[];
    final older = <ChatConversation>[];

    for (final conversation in filtered) {
      final updated = conversation.updatedAt;
      final difference = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(updated.year, updated.month, updated.day)).inDays;

      if (difference == 0) {
        today.add(conversation);
      } else if (difference == 1) {
        yesterday.add(conversation);
      } else {
        older.add(conversation);
      }
    }

    final groups = <_ConversationGroup>[];
    if (today.isNotEmpty) groups.add(_ConversationGroup('Today', today));
    if (yesterday.isNotEmpty) {
      groups.add(_ConversationGroup('Yesterday', yesterday));
    }
    if (older.isNotEmpty) groups.add(_ConversationGroup('Older', older));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedConversations();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBF8), Color(0xFFF6D9E4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE9CAD4)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/lilly_logo.jpg',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lilly',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF473241),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gentle, local, and easy to talk to.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7B6A74),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onNewChat,
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text('New Chat'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Text(
                        'No chats found',
                        style: TextStyle(color: Color(0xFF7B6A74)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(8),
                      children: groups.map((group) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                              child: Text(
                                group.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF8E7985),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...group.items.map((conversation) {
                              final selected =
                                  conversation.id == widget.selectedConversationId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFF7E0E9)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  leading: Icon(
                                    Icons.forum_rounded,
                                    color: selected
                                        ? const Color(0xFFC88298)
                                        : const Color(0xFF7B6A74),
                                  ),
                                  title: Text(
                                    conversation.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF473241),
                                    ),
                                  ),
                                  subtitle: Text(
                                    _subtitle(conversation),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF7B6A74),
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        widget.onRenameConversation(conversation.id);
                                      } else if (value == 'delete') {
                                        widget.onDeleteConversation(conversation.id);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Text('Rename'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                  onTap: () =>
                                      widget.onSelectConversation(conversation.id),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationGroup {
  final String title;
  final List<ChatConversation> items;

  _ConversationGroup(this.title, this.items);
}
