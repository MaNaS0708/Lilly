import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../services/conversation_title_service.dart';
import '../services/local_model_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    LocalModelService? localModelService,
    ConversationTitleService? conversationTitleService,
  }) : _localModelService = localModelService ?? LocalModelService(),
       _conversationTitleService =
           conversationTitleService ?? ConversationTitleService();

  final LocalModelService _localModelService;
  final ConversationTitleService _conversationTitleService;
  final ScrollController scrollController = ScrollController();

  ChatConversation? _conversation;
  File? _selectedImage;
  bool _isSending = false;
  String? _errorMessage;

  ChatConversation? get conversation => _conversation;
  List<ChatMessage> get messages => _conversation?.messages ?? const [];
  File? get selectedImage => _selectedImage;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  void attachConversation(ChatConversation conversation) {
    _conversation = conversation;
    _selectedImage = null;
    _errorMessage = null;
    notifyListeners();
    _scrollToBottomSoon();
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

  void clearActiveConversation() {
    final current = _conversation;
    if (current == null) return;

    _conversation = current.copyWith(
      messages: const [],
      updatedAt: DateTime.now(),
      title: 'New Chat',
    );
    notifyListeners();
  }

  Future<ChatConversation?> sendMessage(String rawText) async {
    final current = _conversation;
    if (current == null) return null;

    final text = rawText.trim();

    if (_isSending) return null;
    if (text.isEmpty && _selectedImage == null) return null;

    final image = _selectedImage;
    final historySnapshot = List<ChatMessage>.from(current.messages);

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      imagePath: image?.path,
      createdAt: DateTime.now(),
    );

    final updatedMessages = [...current.messages, userMessage];
    final updatedConversation = current.copyWith(
      title: _conversationTitleService.buildTitle(
        currentTitle: current.title,
        messages: updatedMessages,
      ),
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    _conversation = updatedConversation;
    _selectedImage = null;
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    _scrollToBottomSoon();

    try {
      final response = await _localModelService.generateResponse(
        prompt: text,
        history: historySnapshot,
        hasImage: image != null,
      );

      if (response.success) {
        final replyMessage = ChatMessage(
          text: response.text,
          isUser: false,
          createdAt: DateTime.now(),
        );

        final conversationWithReply = _conversation!.copyWith(
          messages: [..._conversation!.messages, replyMessage],
          updatedAt: DateTime.now(),
        );

        _conversation = conversationWithReply;
        return conversationWithReply;
      }

      if (response.errorMessage != null) {
        _errorMessage = response.errorMessage;
      }

      return _conversation;
    } catch (_) {
      _errorMessage = 'Something went wrong while generating a reply.';
      return _conversation;
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
