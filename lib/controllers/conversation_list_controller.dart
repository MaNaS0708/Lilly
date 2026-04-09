import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../services/conversation_storage_service.dart';

class ConversationListController extends ChangeNotifier {
  ConversationListController({
    ConversationStorageService? storageService,
  }) : _storageService = storageService ?? ConversationStorageService();

  final ConversationStorageService _storageService;

  final List<ChatConversation> _conversations = [];
  String? _selectedConversationId;
  bool _isLoading = false;
  String? _errorMessage;

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  String? get selectedConversationId => _selectedConversationId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatConversation? get selectedConversation {
    if (_selectedConversationId == null) return null;

    try {
      return _conversations.firstWhere(
        (conversation) => conversation.id == _selectedConversationId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loadedConversations = await _storageService.loadConversations();
      final savedSelectedId = await _storageService.loadSelectedConversationId();

      _conversations
        ..clear()
        ..addAll(loadedConversations);

      if (_conversations.isEmpty) {
        final conversation = createDraftConversation();
        _conversations.add(conversation);
        _selectedConversationId = conversation.id;
        await _persist();
      } else {
        final hasSavedSelection = _conversations.any(
          (conversation) => conversation.id == savedSelectedId,
        );

        _selectedConversationId = hasSavedSelection
            ? savedSelectedId
            : _conversations.first.id;
      }
    } catch (_) {
      _errorMessage = 'Could not load chat history.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ChatConversation createDraftConversation() {
    final now = DateTime.now();
    return ChatConversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'New Chat',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
  }

  Future<ChatConversation> createNewConversation() async {
    final conversation = createDraftConversation();
    _conversations.insert(0, conversation);
    _selectedConversationId = conversation.id;
    await _persist();
    notifyListeners();
    return conversation;
  }

  Future<void> selectConversation(String id) async {
    if (_selectedConversationId == id) return;
    _selectedConversationId = id;
    await _storageService.saveSelectedConversationId(id);
    notifyListeners();
  }

  Future<void> upsertConversation(ChatConversation conversation) async {
    final index = _conversations.indexWhere((item) => item.id == conversation.id);

    if (index == -1) {
      _conversations.insert(0, conversation);
    } else {
      _conversations[index] = conversation;
    }

    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _selectedConversationId = conversation.id;

    await _persist();
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((conversation) => conversation.id == id);

    if (_conversations.isEmpty) {
      final conversation = createDraftConversation();
      _conversations.add(conversation);
      _selectedConversationId = conversation.id;
    } else if (_selectedConversationId == id) {
      _selectedConversationId = _conversations.first.id;
    }

    await _persist();
    notifyListeners();
  }

  Future<void> renameConversation(String id, String title) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return;

    final index = _conversations.indexWhere((conversation) => conversation.id == id);
    if (index == -1) return;

    _conversations[index] = _conversations[index].copyWith(
      title: cleaned,
      updatedAt: DateTime.now(),
    );

    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storageService.saveConversations(_conversations);
    await _storageService.saveSelectedConversationId(_selectedConversationId);
  }
}
