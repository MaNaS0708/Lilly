import 'package:flutter/material.dart';

class MessageTimestamp extends StatelessWidget {
  final DateTime timestamp;
  final Color color;

  const MessageTimestamp({
    super.key,
    required this.timestamp,
    required this.color,
  });

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        _formatTime(timestamp),
        style: TextStyle(
          color: color.withValues(alpha: 0.75),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
