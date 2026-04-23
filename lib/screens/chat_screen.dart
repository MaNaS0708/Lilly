import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/chat_controller.dart';
import '../controllers/conversation_list_controller.dart';
import '../controllers/model_controller.dart';
import '../services/image_picker_service.dart';
import '../services/settings_service.dart';
import '../services/trigger_service.dart';
import '../services/voice_service.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/error_message_banner.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/message_list.dart';
import '../widgets/rename_conversation_dialog.dart';
import 'auto_capture_camera_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final SettingsService _settingsService = SettingsService();
  final TriggerService _triggerService = TriggerService();
  final VoiceService _voiceService = VoiceService();

  late final ModelController _modelController;
  late final ChatController _chatController;
  late final ConversationListController _conversationListController;

  StreamSubscription<VoiceEvent>? _voiceSubscription;

  bool _enableImageInput = true;
  bool _isVoiceListening = false;
  bool _isVoicePreparing = false;
  bool _isVoiceSpeaking = false;
  bool _voiceConversationMode = false;
  bool _pausedTriggerForVoiceChat = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _modelController = ModelController();
    _chatController = ChatController(modelController: _modelController);
    _conversationListController = ConversationListController();
    _listenToVoiceEvents();
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_consumePendingTriggerAction());
    }
  }

  Future<void> _bootstrap() async {
    _enableImageInput = await _settingsService.getEnableImageInput();
    await _conversationListController.load();

    final freshConversation =
        await _conversationListController.createNewConversation();
    _chatController.attachConversation(freshConversation);

    await _modelController.initialize();
    await _consumePendingTriggerAction();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _vibrateInputStart() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> _vibrateInputDone() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> _vibrateResponseStart() async {
    await HapticFeedback.selectionClick();
  }

  Future<void> _vibrateResponseDone() async {
    await HapticFeedback.lightImpact();
  }

  Future<void> _pauseWakeWordForVoiceChat() async {
    if (_pausedTriggerForVoiceChat) return;

    final running = await _triggerService.isTriggerRunning();
    if (!running) return;

    final paused = await _triggerService.pauseForVoiceChat();
    if (paused) {
      _pausedTriggerForVoiceChat = true;
    }
  }

  Future<void> _resumeWakeWordAfterVoiceChat() async {
    if (!_pausedTriggerForVoiceChat) return;

    final resumed = await _triggerService.resumeAfterVoiceChat();
    if (resumed) {
      _pausedTriggerForVoiceChat = false;
    }
  }

  Future<void> _restartVoiceConversationLoop() async {
    if (!_voiceConversationMode || !mounted) return;

    final restarted = await _startVoiceChat();
    if (!restarted && mounted) {
      setState(() {
        _voiceConversationMode = false;
      });
      await _resumeWakeWordAfterVoiceChat();
    }
  }

  void _listenToVoiceEvents() {
    _voiceSubscription = _voiceService.events.listen((event) async {
      if (!mounted) return;

      switch (event.type) {
        case 'ready':
          setState(() {
            _isVoicePreparing = false;
          });
          break;
        case 'listening':
          await _vibrateInputStart();
          setState(() {
            _isVoicePreparing = false;
            _isVoiceListening = true;
            _isVoiceSpeaking = false;
          });
          break;
        case 'partial':
          final partial = (event.text ?? '').trim();
          if (partial.isNotEmpty) {
            _textController.text = partial;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          }
          break;
        case 'final':
          await _vibrateInputDone();
          setState(() {
            _isVoiceListening = false;
          });

          final transcript = (event.text ?? '').trim();
          if (transcript.isEmpty) return;

          if (_shouldCaptureSceneText(transcript)) {
            await _captureAndProcessVisibleText(transcript);
            return;
          }

          _textController.text = transcript;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
          await _sendMessage(speakReply: _voiceConversationMode);
          break;
        case 'stopped':
          setState(() {
            _isVoiceListening = false;
            _isVoicePreparing = false;
          });
          break;
        case 'speaking':
          await _vibrateResponseStart();
          setState(() {
            _isVoiceSpeaking = true;
          });
          break;
        case 'spoken':
          await _vibrateResponseDone();
          if (!mounted) return;
          setState(() {
            _isVoiceSpeaking = false;
          });
          if (_voiceConversationMode &&
              !_isVoiceListening &&
              !_isVoicePreparing &&
              !_modelController.isGenerating) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            await _restartVoiceConversationLoop();
          }
          break;
        case 'error':
          final shouldResumeTrigger = _voiceConversationMode;
          setState(() {
            _isVoiceListening = false;
            _isVoicePreparing = false;
            _isVoiceSpeaking = false;
            _voiceConversationMode = false;
          });
          if (shouldResumeTrigger) {
            await _resumeWakeWordAfterVoiceChat();
          }
          _chatController.showError(event.message ?? 'Voice capture failed.');
          break;
      }
    });
  }

  bool _shouldCaptureSceneText(String transcript) {
    final normalized = transcript.toLowerCase();
    return normalized.contains("what's in front of me") ||
        normalized.contains('what is in front of me') ||
        normalized.contains("read what's in front of me") ||
        normalized.contains('read what is in front of me') ||
        normalized.contains("what's written in front of me") ||
        normalized.contains('what is written in front of me') ||
        normalized.contains('read the text in front of me') ||
        normalized.contains('scan the text in front of me') ||
        normalized.contains('what do you see in front of me') ||
        normalized.contains('tell me what is in front of me') ||
        normalized.contains("tell me what's in front of me") ||
        normalized.contains('see what is in front of me') ||
        normalized.contains("see what's in front of me");
  }

  Future<void> _captureAndProcessVisibleText(String transcript) async {
    if (!_enableImageInput) {
      _chatController.showError('Image input is disabled in settings.');
      return;
    }

    try {
      final image = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          builder: (_) => const AutoCaptureCameraScreen(),
          fullscreenDialog: true,
        ),
      );

      if (image == null) {
        await _restartVoiceConversationLoop();
        return;
      }

      _chatController.setSelectedImage(image);
      _textController.text = transcript;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
      await _sendMessage(speakReply: _voiceConversationMode);
    } catch (e) {
      _chatController.showError(e.toString());
      await _restartVoiceConversationLoop();
    }
  }

  Future<void> _consumePendingTriggerAction() async {
    final action = await _triggerService.consumePendingLaunchAction();
    if (!mounted || action == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      switch (action) {
        case 'voice_chat':
          await _startVoiceConversation();
          break;
        case 'open_app':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lilly opened from the assistant trigger.'),
              duration: Duration(milliseconds: 1200),
            ),
          );
          break;
      }
    });
  }

  Future<void> _startVoiceConversation() async {
    await _pauseWakeWordForVoiceChat();

    if (!mounted) return;
    setState(() {
      _voiceConversationMode = true;
    });

    final started = await _startVoiceChat();
    if (!started && mounted) {
      setState(() {
        _voiceConversationMode = false;
      });
      await _resumeWakeWordAfterVoiceChat();
    }
  }

  Future<bool> _startVoiceChat() async {
    if (_isVoicePreparing || _isVoiceListening) return true;

    setState(() {
      _isVoicePreparing = true;
    });

    final initialized = await _voiceService.initializeVoiceModel();
    if (!initialized) {
      if (!mounted) return false;
      setState(() {
        _isVoicePreparing = false;
      });
      _chatController.showError('Voice chat is not ready on this device yet.');
      return false;
    }

    final started = await _voiceService.startListening();
    if (!mounted) return started;

    if (!started) {
      setState(() {
        _isVoicePreparing = false;
        _isVoiceListening = false;
      });
      _chatController.showError('Could not start speech recognition.');
      return false;
    }

    return true;
  }

  Future<void> _stopVoiceChat() async {
    await _voiceService.stopListening();
    await _voiceService.stopSpeaking();
    if (!mounted) return;
    setState(() {
      _isVoiceListening = false;
      _isVoicePreparing = false;
      _isVoiceSpeaking = false;
      _voiceConversationMode = false;
    });
    await _resumeWakeWordAfterVoiceChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceSubscription?.cancel();
    _textController.dispose();
    _chatController.dispose();
    _conversationListController.dispose();
    _modelController.shutdown();
    _modelController.dispose();
    _voiceService.dispose();
    if (_pausedTriggerForVoiceChat) {
      unawaited(_resumeWakeWordAfterVoiceChat());
    }
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
      _chatController.showError(e.toString());
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
      _chatController.showError(e.toString());
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

  Future<void> _sendMessage({bool speakReply = false}) async {
    final text = _textController.text.trim();
    final hasImage = _chatController.selectedImage != null;

    if (text.isEmpty && !hasImage) return;
    if (_modelController.isGenerating || _modelController.isLoading) return;

    final ready = await _modelController.ensureReady();
    if (!ready) {
      _chatController.showError(
        _modelController.errorMessage ??
            'The local model could not be prepared on this device.',
      );
      return;
    }

    await _vibrateInputDone();
    await _vibrateResponseStart();

    final updatedConversation = await _chatController.sendMessage(text);
    if (updatedConversation != null) {
      _textController.clear();
      await _conversationListController.upsertConversation(updatedConversation);

      final lastMessage = updatedConversation.messages.isEmpty
          ? null
          : updatedConversation.messages.last;

      if (lastMessage != null && !lastMessage.isUser) {
        await _vibrateResponseDone();
      }

      if (speakReply && lastMessage != null && !lastMessage.isUser) {
        await _voiceService.speakReply(lastMessage.text);
      }
    }
  }

  Future<void> _createNewChat() async {
    final conversation =
        await _conversationListController.createNewConversation();
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

  String _loadingLabel() {
    if (_isVoicePreparing) return 'Getting Lilly ready to listen...';
    if (_isVoiceListening) return 'Listening...';
    if (_isVoiceSpeaking) return 'Lilly is replying...';
    if (_modelController.isLoading) return 'Loading Lilly on this device...';
    if (_modelController.isGenerating) return 'Lilly is thinking...';
    return 'Working...';
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
        final isBusy = _chatController.isSending ||
            _modelController.isLoading ||
            _isVoicePreparing ||
            _isVoiceListening ||
            _isVoiceSpeaking;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFBF8), Color(0xFFF9E6ED), Color(0xFFFDF8F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
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
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 8,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/lilly_logo.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activeConversation?.title ?? 'Lilly',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: (_isVoiceListening ||
                          _isVoicePreparing ||
                          _isVoiceSpeaking ||
                          _voiceConversationMode)
                      ? _stopVoiceChat
                      : (isBusy ? null : _startVoiceConversation),
                  icon: Icon(
                    (_isVoiceListening ||
                            _isVoicePreparing ||
                            _isVoiceSpeaking ||
                            _voiceConversationMode)
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                  ),
                ),
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
                    isLoading: isBusy,
                    loadingLabel: _loadingLabel(),
                  ),
                ),
                MessageInputBar(
                  controller: _textController,
                  selectedImage: _chatController.selectedImage,
                  isSending: isBusy,
                  onPickImage: _showImageSourceSheet,
                  onRemoveImage: _chatController.removeSelectedImage,
                  onSend: () => _sendMessage(speakReply: _voiceConversationMode),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
