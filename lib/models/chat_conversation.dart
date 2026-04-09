import 'chat_message.dart';

class ChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final String? summary;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.summary,
  });

  bool get isEmpty => messages.isEmpty;

  ChatConversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    String? summary,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      summary: summary ?? this.summary,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'summary': summary,
      'messages': messages.map((message) => message.toMap()).toList(),
    };
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'New Chat',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      summary: map['summary'] as String?,
      messages: ((map['messages'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => ChatMessage.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
