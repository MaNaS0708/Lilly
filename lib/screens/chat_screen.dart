import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/image_picker_service.dart';
import '../widgets/chat_bubble.dart';
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

    await Future<void>.delayed(const Duration(milliseconds: 700));

    setState(() {
      _messages.add(
        const ChatMessage(
          text:
              'This is a placeholder assistant reply. Later we can connect your local model here.',
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
                ? const _EmptyState()
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Start a new conversation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send text, attach an image, or do both.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
