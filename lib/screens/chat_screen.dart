import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/image_picker_service.dart';
import '../services/local_ai_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/empty_chat_state.dart';
import '../widgets/message_input_bar.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final LocalAiService _localAiService = LocalAiService();

  File? _selectedImage;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final image = await ImagePickerService.pickFromCamera();
    if (image == null) return;

    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePickerService.pickFromGallery();
    if (image == null) return;

    setState(() {
      _selectedImage = image;
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _showImageSourceSheet() {
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
    final text = _controller.text.trim();

    if (text.isEmpty && _selectedImage == null) return;
    if (_isSending) return;

    final image = _selectedImage;
    final historySnapshot = List<ChatMessage>.from(_messages);

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          imageFile: image,
        ),
      );
      _controller.clear();
      _selectedImage = null;
    });

    final reply = await _localAiService.generateReply(
      prompt: text,
      history: historySnapshot,
      hasImage: image != null,
    );

    if (!mounted) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: reply,
          isUser: false,
        ),
      );
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Chat'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const EmptyChatState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: _messages[index]);
                    },
                  ),
          ),
          MessageInputBar(
            controller: _controller,
            selectedImage: _selectedImage,
            isSending: _isSending,
            onPickImage: _showImageSourceSheet,
            onRemoveImage: _removeSelectedImage,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
