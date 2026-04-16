import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../controllers/conversation_list_controller.dart';
import '../controllers/model_controller.dart';
import '../services/image_picker_service.dart';
import '../services/settings_service.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/error_message_banner.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/message_list.dart';
import '../widgets/rename_conversation_dialog.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final SettingsService _settingsService = SettingsService();

  late final ModelController _modelController;
  late final ChatController _chatController;
  late final ConversationListController _conversationListController;

  bool _enableImageInput = true;

  @override
  void initState() {
    super.initState();
    _modelController = ModelController();
    _chatController = ChatController(modelController: _modelController);
    _conversationListController = ConversationListController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _enableImageInput = await _settingsService.getEnableImageInput();
    await _conversationListController.load();

    final selected = _conversationListController.selectedConversation;
    if (selected != null) {
      _chatController.attachConversation(selected);
    }

    if (mounted) {
      setState(() {});
    }
  }


  @override
  void dispose() {
    _textController.dispose();
    _chatController.dispose();
    _conversationListController.dispose();
    _modelController.shutdown();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (!_enableImageInput) {
      _chatController.showError('Image input is disabled in settings.');
      return;
    }

    try {
      final File? image = await ImagePickerService.pickFromCamera();
      if (image == null) return;
      _chatController.setSelectedImage(image);
    } catch (e) {
      _chatController.showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickFromGallery() async {
    if (!_enableImageInput) {
      _chatController.showError('Image input is disabled in settings.');
      return;
    }

    try {
      final File? image = await ImagePickerService.pickFromGallery();
      if (image == null) return;
      _chatController.setSelectedImage(image);
    } catch (e) {
      _chatController.showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _refreshSettings() async {
    final enabled = await _settingsService.getEnableImageInput();
    if (!mounted) return;

    await _conversationListController.refreshPersistencePreference();

    setState(() {
      _enableImageInput = enabled;
    });
  }

  void _showImageSourceSheet() {
    if (!_enableImageInput) {
      _chatController.showError('Image input is disabled in settings.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final hasImage = _chatController.selectedImage != null;

    if (text.isEmpty && !hasImage) return;

    if (!_modelController.isReady) {
      await _modelController.initialize();

      if (!_modelController.isReady) {
        return;
      }
    }

    final updatedConversation = await _chatController.sendMessage(text);
    if (updatedConversation != null) {
      _textController.clear();
      await _conversationListController.upsertConversation(updatedConversation);
    }
  }


  Future<void> _createNewChat() async {
    final conversation = await _conversationListController.createNewConversation();
    _chatController.attachConversation(conversation);

    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _selectConversation(String id) async {
    await _conversationListController.selectConversation(id);
    final selected = _conversationListController.selectedConversation;
    if (selected != null) {
      _chatController.attachConversation(selected);
    }

    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _renameConversation(String id) async {
    final conversation = _conversationListController.conversations.firstWhere(
      (item) => item.id == id,
    );

    final newName = await RenameConversationDialog.show(
      context,
      initialValue: conversation.title,
    );

    if (newName == null || newName.trim().isEmpty) return;

    await _conversationListController.renameConversation(id, newName);

    final selected = _conversationListController.selectedConversation;
    if (selected != null) {
      _chatController.attachConversation(selected);
    }
  }

  Future<void> _deleteConversation(String id) async {
    final shouldDelete = await ConfirmActionDialog.show(
      context,
      title: 'Delete chat?',
      message: 'This conversation will be removed from this device.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
    );

    if (!shouldDelete) return;

    await _conversationListController.deleteConversation(id);
    final selected = _conversationListController.selectedConversation;
    if (selected != null) {
      _chatController.attachConversation(selected);
    }

    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(modelController: _modelController),
      ),
    );
    await _refreshSettings();
    await _modelController.refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _chatController,
        _conversationListController,
        _modelController,
      ]),
      builder: (context, _) {
        final activeConversation = _chatController.conversation;

        return Scaffold(
          drawer: ConversationDrawer(
            conversations: _conversationListController.conversations,
            selectedConversationId:
                _conversationListController.selectedConversation?.id,
            onNewChat: _createNewChat,
            onSelectConversation: _selectConversation,
            onRenameConversation: _renameConversation,
            onDeleteConversation: _deleteConversation,
          ),
          appBar: AppBar(
            title: Text(activeConversation?.title ?? 'Lilly'),
            actions: [
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_chatController.errorMessage != null)
                ErrorMessageBanner(
                  message: _chatController.errorMessage!,
                  onDismiss: _chatController.dismissError,
                ),
              Expanded(
                child: MessageList(
                  messages: _chatController.messages,
                  scrollController: _chatController.scrollController,
                  isLoading: _chatController.isSending,
                ),
              ),
              MessageInputBar(
                controller: _textController,
                selectedImage: _chatController.selectedImage,
                isSending: _chatController.isSending,
                onPickImage: _showImageSourceSheet,
                onRemoveImage: _chatController.removeSelectedImage,
                onSend: _sendMessage,
              ),
            ],
          ),
          floatingActionButton: activeConversation == null
              ? FloatingActionButton.extended(
                  onPressed: _createNewChat,
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text('New Chat'),
                )
              : null,
        );
      },
    );
  }
}
