import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/model_controller.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/model_request.dart';
import '../services/conversation_title_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ModelController modelController,
    ConversationTitleService? conversationTitleService,
  }) : _modelController = modelController,
       _conversationTitleService =
           conversationTitleService ?? ConversationTitleService() {
    scrollController.addListener(_handleScrollPositionChanged);
  }

  final ModelController _modelController;
  final ConversationTitleService _conversationTitleService;
  final ScrollController scrollController = ScrollController();

  ChatConversation? _conversation;
  File? _selectedImage;
  String? _errorMessage;
  bool _stickToBottom = true;

  ChatConversation? get conversation => _conversation;
  List<ChatMessage> get messages => _conversation?.messages ?? const [];
  File? get selectedImage => _selectedImage;
  bool get isSending => _modelController.isGenerating;
  String? get errorMessage => _errorMessage ?? _modelController.errorMessage;

  void attachConversation(ChatConversation conversation) {
    _conversation = conversation;
    _selectedImage = null;
    _errorMessage = null;
    notifyListeners();
    _scrollToBottomSoon(force: true);
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
    _errorMessage = _friendlyError(message);
    notifyListeners();
  }

  void dismissError() {
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
    if (isSending) return null;
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
    var workingConversation = current.copyWith(
      title: _conversationTitleService.buildTitle(
        currentTitle: current.title,
        messages: updatedMessages,
      ),
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    _conversation = workingConversation;
    _selectedImage = null;
    _errorMessage = null;
    notifyListeners();
    _scrollToBottomSoon(force: true);

    if (!_modelController.isReady) {
      const modelError = 'Local model is still loading. Try again in a moment.';
      _errorMessage = modelError;
      notifyListeners();
      return workingConversation;
    }

    final result = await _modelController.generateResponse(
      ModelRequest(
        prompt: text,
        history: historySnapshot,
        imagePath: image?.path,
      ),
    );

    if (!result.success) {
      final failureText = _friendlyError(
        result.errorMessage ?? 'Failed to generate a response.',
      );

      final assistantError = ChatMessage(
        text: failureText,
        isUser: false,
        createdAt: DateTime.now(),
      );

      workingConversation = _conversation!.copyWith(
        messages: [..._conversation!.messages, assistantError],
        updatedAt: DateTime.now(),
      );

      _conversation = workingConversation;
      _errorMessage = failureText;
      notifyListeners();
      _scrollToBottomSoon();
      return workingConversation;
    }

    final replyMessage = ChatMessage(
      text: result.text,
      isUser: false,
      createdAt: DateTime.now(),
    );

    final conversationWithReply = _conversation!.copyWith(
      messages: [..._conversation!.messages, replyMessage],
      updatedAt: DateTime.now(),
    );

    _conversation = conversationWithReply;
    notifyListeners();
    _scrollToBottomSoon();
    return conversationWithReply;
  }

  String _friendlyError(String raw) {
    final message = raw.replaceFirst('Exception: ', '').trim();
    final lower = message.toLowerCase();

    if (lower.contains('corrupted') ||
        lower.contains('incomplete') ||
        lower.contains('invalid')) {
      return 'The local model file looks incomplete or damaged. Delete the model from Settings and download it again.';
    }

    if (lower.contains('not initialized') || lower.contains('not ready')) {
      return 'The local model is not ready yet. Wait for it to finish loading, then try again.';
    }

    if (lower.contains('native library') ||
        lower.contains('jni') ||
        lower.contains('litert')) {
      return 'Lilly could not start the on-device model on this phone. Try reopening the app. If it still fails, delete the model and download it again.';
    }

    if (lower.contains('download')) {
      return 'The model setup is not complete yet. Go back to setup, finish the download, and try again.';
    }

    return message;
  }

  void _handleScrollPositionChanged() {
    if (!scrollController.hasClients) return;

    final remaining =
        scrollController.position.maxScrollExtent - scrollController.offset;
    _stickToBottom = remaining < 120;
  }

  void _scrollToBottomSoon({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      if (!force && !_stickToBottom) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    scrollController
      ..removeListener(_handleScrollPositionChanged)
      ..dispose();
    super.dispose();
  }
}
