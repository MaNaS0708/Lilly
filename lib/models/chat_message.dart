class ChatMessage {
  final String text;
  final bool isUser;
  final String? imagePath;
  final DateTime createdAt;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePath,
    required this.createdAt,
  });

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get hasText => text.trim().isNotEmpty;

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    String? imagePath,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: (map['text'] as String?) ?? '',
      isUser: (map['isUser'] as bool?) ?? false,
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
