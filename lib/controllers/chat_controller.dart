import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/local_ai_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    LocalAiService? localAiService,
  }) : _localAiService = localAiService ?? LocalAiService();

  final LocalAiService _localAiService;

  final List<ChatMessage> _messages = [];
  final ScrollController scrollController = ScrollController();

  File? _selectedImage;
  bool _isSending = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  File? get selectedImage => _selectedImage;
  bool get isSending => _isSending;

  void setSelectedImage(File? image) {
    _selectedImage = image;
    notifyListeners();
  }

  void removeSelectedImage() {
    _selectedImage = null;
    notifyListeners();
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();

    if (_isSending) return;
    if (text.isEmpty && _selectedImage == null) return;

    final image = _selectedImage;
    final historySnapshot = List<ChatMessage>.from(_messages);

    _isSending = true;
    _messages.add(
      ChatMessage(
        text: text,
        isUser: true,
        imageFile: image,
      ),
    );
    _selectedImage = null;
    notifyListeners();
    _scrollToBottomSoon();

    try {
      final reply = await _localAiService.generateReply(
        prompt: text,
        history: historySnapshot,
        hasImage: image != null,
      );

      _messages.add(
        ChatMessage(
          text: reply,
          isUser: false,
        ),
      );
    } finally {
      _isSending = false;
      notifyListeners();
      _scrollToBottomSoon();
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}
