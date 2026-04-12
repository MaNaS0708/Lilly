import 'package:flutter/material.dart';

class ErrorMessageBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorMessageBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFBE123C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(
                color: Color(0xFF881337),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
              color: const Color(0xFF881337),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
