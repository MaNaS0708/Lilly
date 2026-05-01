import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/model_request.dart';
import '../models/model_result.dart';
import '../services/conversation_title_service.dart';
import '../services/text_recognition_service.dart';
import '../services/visual_intent_service.dart';
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

  static const int _maxHistoryMessages = 0;
  static const int _maxExtractedTextChars = 1400;

  final ModelController _modelController;
  final ConversationTitleService _conversationTitleService;
  final TextRecognitionService _textRecognitionService;
  final ScrollController scrollController = ScrollController();

  ChatConversation? _conversation;
  File? _selectedImage;
  String? _errorMessage;
  bool _stickToBottom = true;
  bool _hasStreamingReply = false;

  ChatConversation? get conversation => _conversation;
  List<ChatMessage> get messages => _conversation?.messages ?? const [];
  File? get selectedImage => _selectedImage;
  bool get isSending => _modelController.isGenerating;
  bool get hasStreamingReply => _hasStreamingReply;
  String? get errorMessage => _errorMessage ?? _modelController.errorMessage;

  void attachConversation(ChatConversation conversation) {
    _conversation = conversation;
    _selectedImage = null;
    _errorMessage = null;
    _hasStreamingReply = false;
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
    _hasStreamingReply = false;
    notifyListeners();
    _scrollToBottomSoon(force: true);

    if (!_modelController.isReady) {
      const modelError = 'Local model is still loading. Try again in a moment.';
      _errorMessage = modelError;
      notifyListeners();
      return workingConversation;
    }

    final result = image == null
        ? await _modelController.generateResponse(
            ModelRequest(
              prompt: text,
              history: historySnapshot,
              imagePath: null,
              conversationId: current.id,
            ),
            onPartialText: _updateStreamingReply,
          )
        : await _generateImageAwareResponse(
            userText: text,
            image: image,
            history: historySnapshot,
            conversationId: current.id,
            onPartialText: _updateStreamingReply,
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
        messages: _replaceOrAppendAssistantMessage(assistantError),
        updatedAt: DateTime.now(),
      );

      _conversation = workingConversation;
      _errorMessage = failureText;
      _hasStreamingReply = false;
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
      messages: _replaceOrAppendAssistantMessage(replyMessage),
      updatedAt: DateTime.now(),
    );

    _conversation = conversationWithReply;
    _hasStreamingReply = false;
    notifyListeners();
    _scrollToBottomSoon();
    return conversationWithReply;
  }

  Future<ModelResult> _generateImageAwareResponse({
    required String userText,
    required File image,
    required List<ChatMessage> history,
    required String conversationId,
    required void Function(String text) onPartialText,
  }) async {
    final visionResult = await _modelController.generateResponse(
      ModelRequest(
        prompt: _buildVisionPrompt(userText: userText),
        history: history,
        imagePath: image.path,
        conversationId: conversationId,
      ),
      suppressError: true,
    );

    if (visionResult.success && visionResult.text.trim().isNotEmpty) {
      return visionResult;
    }

    try {
      final extractedText = await _textRecognitionService.extractTextFromFile(
        image.path,
      );

      if (extractedText.trim().isEmpty) {
        return ModelResult.failure(
          errorMessage:
              visionResult.errorMessage ??
              'I could not process that image clearly. Try another photo with better lighting and framing.',
        );
      }

      return _modelController.generateResponse(
        ModelRequest(
          prompt: _buildPromptFromImageText(
            userText: userText,
            extractedText: extractedText,
          ),
          history: history,
          imagePath: null,
          conversationId: conversationId,
        ),
        onPartialText: onPartialText,
      );
    } catch (e) {
      return ModelResult.failure(
        errorMessage:
            visionResult.errorMessage ??
            'I could not process that image clearly. Try another photo with better lighting and framing.',
      );
    }
  }

  List<ChatMessage> _trimHistory(List<ChatMessage> source) {
    if (_maxHistoryMessages <= 0) {
      return const <ChatMessage>[];
    }

    if (source.length <= _maxHistoryMessages) {
      return List<ChatMessage>.from(source);
    }

    return List<ChatMessage>.from(
      source.sublist(source.length - _maxHistoryMessages),
    );
  }

  void _updateStreamingReply(String text) {
    final current = _conversation;
    if (current == null) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final streamingMessage = ChatMessage(
      text: cleanText,
      isUser: false,
      createdAt: DateTime.now(),
    );

    _conversation = current.copyWith(
      messages: _replaceOrAppendAssistantMessage(streamingMessage),
      updatedAt: DateTime.now(),
    );
    _hasStreamingReply = true;
    notifyListeners();
    _scrollToBottomSoon();
  }

  List<ChatMessage> _replaceOrAppendAssistantMessage(ChatMessage message) {
    final currentMessages = _conversation?.messages ?? const <ChatMessage>[];
    if (_hasStreamingReply &&
        currentMessages.isNotEmpty &&
        !currentMessages.last.isUser) {
      return [...currentMessages.take(currentMessages.length - 1), message];
    }

    return [...currentMessages, message];
  }

  String _buildVisionPrompt({required String userText}) {
    final cleanUserText = userText.trim();
    final request = cleanUserText.isEmpty ? 'What is this?' : cleanUserText;

    return '''
      You are Lilly using the attached image as the main source.

      User request:
      $request

      ${_visionInstructionFor(request)}

      Rules:
      - Answer the user's actual request, not a generic template.
      - Start with the direct answer.
      - If the user asks what you can see, describe the visible scene or main objects first.
      - If it is a product, identify object type, brand, product name, visible label text, and likely use.
      - If it is a document, sign, menu, label, receipt, or screen, read the important visible text and explain it briefly.
      - Never say "the text you provided".
      - Never mention OCR, fallback, native vision, prompt, or model.
      - If uncertain, say "It looks like..." and give the best likely answer.
      - Be mature, natural, and concise.
    ''';
  }

  String _buildPromptFromImageText({
    required String userText,
    required String extractedText,
  }) {
    final cleanUserText = userText.trim();
    final request = cleanUserText.isEmpty ? 'What is this?' : cleanUserText;
    var cleanExtractedText = extractedText.trim();

    if (cleanExtractedText.length > _maxExtractedTextChars) {
      cleanExtractedText = cleanExtractedText.substring(
        0,
        _maxExtractedTextChars,
      );
    }

    return '''
      Internal context: direct image vision was unavailable, but readable visible text was found in the user's image.
      Treat the text below as text seen in the image.
      Do not reveal this internal context.

      User request:
      $request

      ${_visionInstructionFor(request)}

      Visible text from the image:
      $cleanExtractedText

      Rules:
      - Never say "the text you provided".
      - Never mention OCR, fallback, native vision, extracted text, prompt, or model.
      - If the user asks what you can see, answer from the visible text clues naturally.
      - If the text looks like a product label, infer the likely product, brand, object type, and use.
      - If the text looks incomplete or noisy, say "It appears to be..." and give the best likely answer.
      - Do not say "text is not enough" unless there is truly no useful clue.
      - Keep the answer short and direct.
    ''';
  }

  String _visionInstructionFor(String userText) {
    if (VisualIntentService.asksToReadText(userText)) {
      return '''
        Task:
        Read or summarize the important visible text.
        If the user asks for a specific field like expiry, price, ingredients, address, or instructions, answer that first.
      ''';
    }

    if (VisualIntentService.asksToDescribeScene(userText)) {
      return '''
        Task:
        Describe what is visible in the image.
        Mention the main objects, scene, people if any, readable text if useful, and any important context.
      ''';
    }

    if (VisualIntentService.asksToIdentifyObject(userText)) {
      return '''
        Task:
        Identify the main object or product.
        Mention what it is, visible brand/name, label clues, and likely purpose.
      ''';
    }

    return '''
      Task:
      Use the image to answer the user's question directly.
      Prefer concrete visual details over generic wording.
    ''';
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

    if (lower.contains('nativesendmessage') ||
        lower.contains('failed to invoke the compiled model') ||
        lower.contains('compiled_model_executor')) {
      return 'Voice chat hit a temporary on-device model failure. Lilly will retry with a safer backend automatically. If it still happens, reopen the app and try again.';
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

    if (lower.contains('image') &&
        (lower.contains('native') ||
            lower.contains('vision') ||
            lower.contains('compiled model'))) {
      return 'Lilly could not process that image with the on-device model. It will fall back to readable text when possible.';
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
    scrollController.removeListener(_handleScrollPositionChanged);
    scrollController.dispose();
    super.dispose();
  }
}
