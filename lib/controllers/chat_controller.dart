import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/model_request.dart';
import '../services/conversation_title_service.dart';
import '../services/text_recognition_service.dart';
import 'model_controller.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ModelController modelController,
    ConversationTitleService? conversationTitleService,
    TextRecognitionService? textRecognitionService,
  }) : _modelController = modelController,
       _conversationTitleService =
           conversationTitleService ?? ConversationTitleService(),
       _textRecognitionService =
           textRecognitionService ?? TextRecognitionService() {
    scrollController.addListener(_handleScrollPositionChanged);
  }

  static const int _maxHistoryMessages = 5;
  static const int _maxExtractedTextChars = 3200;

  final ModelController _modelController;
  final ConversationTitleService _conversationTitleService;
  final TextRecognitionService _textRecognitionService;
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
    final historySnapshot = _trimHistory(current.messages);

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

    var effectivePrompt = text;

    if (image != null) {
      try {
        final extractedText = await _textRecognitionService.extractTextFromFile(
          image.path,
        );

        if (extractedText.isEmpty) {
          final failureText =
              'I could not find readable text in that image. I can still help well with books, signs, labels, and documents when the text is visible.';

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

        effectivePrompt = _buildPromptFromImageText(
          userText: text,
          extractedText: extractedText,
        );
      } catch (e) {
        final failureText = _friendlyError(
          'Failed to read text from the selected image: $e',
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
    }

    final result = await _modelController.generateResponse(
      ModelRequest(
        prompt: effectivePrompt,
        history: historySnapshot,
        imagePath: null,
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

  List<ChatMessage> _trimHistory(List<ChatMessage> source) {
    if (source.length <= _maxHistoryMessages) {
      return List<ChatMessage>.from(source);
    }

    return List<ChatMessage>.from(
      source.sublist(source.length - _maxHistoryMessages),
    );
  }

  String _buildPromptFromImageText({
    required String userText,
    required String extractedText,
  }) {
    final cleanUserText = userText.trim();
    var cleanExtractedText = extractedText.trim();

    if (cleanExtractedText.length > _maxExtractedTextChars) {
      cleanExtractedText =
          cleanExtractedText.substring(0, _maxExtractedTextChars);
    }

    if (_looksLikeFrontOfMeIntent(cleanUserText)) {
      return '''
The user asked what is in front of them.

You only have text extracted from the image, not full visual understanding.
Use the extracted text to infer the most likely object in a careful and honest way.

If the text strongly looks like a book cover, say it appears to be a book and mention the likely title and author.
If it looks like a sign, package, document, label, poster, notebook, or menu, say that naturally.
Do not invent colors, shapes, or surrounding objects that are not supported by the text.
If the text is incomplete or noisy, say that briefly and still help.

Answer warmly, clearly, and simply.
Keep the answer natural, like a kind person talking.

Extracted text from the camera image:
$cleanExtractedText
''';
    }

    if (cleanUserText.isEmpty) {
      return '''
Read the following text extracted from an image and help the user with it.

Answer in a warm, simple, easy-to-understand way.

Extracted image text:
$cleanExtractedText
''';
    }

    return '''
$cleanUserText

Use this text extracted from the attached image:

$cleanExtractedText

Answer warmly, clearly, and simply.
''';
  }

  bool _looksLikeFrontOfMeIntent(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains("what's in front of me") ||
        normalized.contains('what is in front of me') ||
        normalized.contains("read what's in front of me") ||
        normalized.contains('read what is in front of me') ||
        normalized.contains("what's written in front of me") ||
        normalized.contains('what is written in front of me') ||
        normalized.contains('read the text in front of me') ||
        normalized.contains('scan the text in front of me') ||
        normalized.contains('what do you see in front of me');
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

    if (lower.contains('read text from the selected image')) {
      return 'Lilly could not read text from that image. Try a clearer photo or better lighting.';
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
    unawaited(_textRecognitionService.dispose());
    scrollController
      ..removeListener(_handleScrollPositionChanged)
      ..dispose();
    super.dispose();
  }
}
