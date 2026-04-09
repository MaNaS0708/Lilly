import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_storage_service.dart';
import '../services/local_model_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    LocalModelService? localModelService,
    ChatStorageService? chatStorageService,
  }) : _localModelService = localModelService ?? LocalModelService(),
       _chatStorageService = chatStorageService ?? ChatStorageService();

  final LocalModelService _localModelService;
  final ChatStorageService _chatStorageService;

  final List<ChatMessage> _messages = [];
  final ScrollController scrollController = ScrollController();

  File? _selectedImage;
  bool _isSending = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  File? get selectedImage => _selectedImage;
  bool get isSending => _isSending;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get errorMessage => _errorMessage;

  Future<void> loadMessages() async {
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final savedMessages = await _chatStorageService.loadMessages();
      _messages
        ..clear()
        ..addAll(savedMessages);
    } catch (_) {
      _errorMessage = 'Could not load previous messages.';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
      _scrollToBottomSoon();
    }
  }

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

  Future<void> clearMessages() async {
    _messages.clear();
    await _chatStorageService.clearMessages();
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
        imagePath: image?.path,
        createdAt: DateTime.now(),
      ),
    );
    _selectedImage = null;
    notifyListeners();
    _scrollToBottomSoon();
    await _persistMessages();

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
            createdAt: DateTime.now(),
          ),
        );
        await _persistMessages();
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

  Future<void> _persistMessages() async {
    try {
      await _chatStorageService.saveMessages(_messages);
    } catch (_) {
      _errorMessage = 'Could not save chat history locally.';
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
