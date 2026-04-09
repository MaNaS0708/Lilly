import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../services/conversation_storage_service.dart';
import '../services/settings_service.dart';

class ConversationListController extends ChangeNotifier {
  ConversationListController({
    ConversationStorageService? storageService,
    SettingsService? settingsService,
  }) : _storageService = storageService ?? ConversationStorageService(),
       _settingsService = settingsService ?? SettingsService();

  final ConversationStorageService _storageService;
  final SettingsService _settingsService;

  final List<ChatConversation> _conversations = [];
  String? _selectedConversationId;
  bool _isLoading = false;
  bool _saveChatsLocally = true;
  String? _errorMessage;

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  String? get selectedConversationId => _selectedConversationId;
  bool get isLoading => _isLoading;
  bool get saveChatsLocally => _saveChatsLocally;
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
      _saveChatsLocally = await _settingsService.getSaveChatsLocally();

      final loadedConversations = _saveChatsLocally
          ? await _storageService.loadConversations()
          : <ChatConversation>[];

      final savedSelectedId = _saveChatsLocally
          ? await _storageService.loadSelectedConversationId()
          : null;

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

  Future<void> refreshPersistencePreference() async {
    final previous = _saveChatsLocally;
    _saveChatsLocally = await _settingsService.getSaveChatsLocally();

    if (previous == _saveChatsLocally) {
      notifyListeners();
      return;
    }

    if (!_saveChatsLocally) {
      await _storageService.clearAll();
    } else {
      await _persist();
    }

    notifyListeners();
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
    await _persistSelectionOnly();
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
    if (_saveChatsLocally) {
      await _storageService.saveConversations(_conversations);
      await _storageService.saveSelectedConversationId(_selectedConversationId);
    }
  }

  Future<void> _persistSelectionOnly() async {
    if (_saveChatsLocally) {
      await _storageService.saveSelectedConversationId(_selectedConversationId);
    }
  }
}
