import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/local_model_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    LocalModelService? localModelService,
  }) : _localModelService = localModelService ?? LocalModelService();

  final LocalModelService _localModelService;

  final List<ChatMessage> _messages = [];
  final ScrollController scrollController = ScrollController();

  File? _selectedImage;
  bool _isSending = false;
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  File? get selectedImage => _selectedImage;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  void setSelectedImage(File? image) {
    _selectedImage = image;
    _errorMessage = null;
    notifyListeners();
  }

  void removeSelectedImage() {
    _selectedImage = null;
    notifyListeners();
  }

  void showError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void dismissError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();

    if (_isSending) return;
    if (text.isEmpty && _selectedImage == null) return;

    final image = _selectedImage;
    final historySnapshot = List<ChatMessage>.from(_messages);

    _isSending = true;
    _errorMessage = null;
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
      final response = await _localModelService.generateResponse(
        prompt: text,
        history: historySnapshot,
        hasImage: image != null,
      );

      if (response.success) {
        _messages.add(
          ChatMessage(
            text: response.text,
            isUser: false,
          ),
        );
      } else if (response.errorMessage != null) {
        _errorMessage = response.errorMessage;
      }
    } catch (_) {
      _errorMessage = 'Something went wrong while generating a reply.';
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
