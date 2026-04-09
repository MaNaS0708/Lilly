import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../services/image_picker_service.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/message_list.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  late final ChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = ChatController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final File? image = await ImagePickerService.pickFromCamera();
    if (image == null) return;
    _chatController.setSelectedImage(image);
  }

  Future<void> _pickFromGallery() async {
    final File? image = await ImagePickerService.pickFromGallery();
    if (image == null) return;
    _chatController.setSelectedImage(image);
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
    final text = _textController.text;
    _textController.clear();
    await _chatController.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _chatController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vision Chat'),
            centerTitle: false,
          ),
          body: Column(
            children: [
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
        );
      },
    );
  }
}
