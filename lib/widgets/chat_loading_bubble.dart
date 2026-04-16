import 'package:flutter/material.dart';

class ChatLoadingBubble extends StatefulWidget {
  const ChatLoadingBubble({
    super.key,
    required this.label,
  });

  final String label;

  @override
  State<ChatLoadingBubble> createState() => _ChatLoadingBubbleState();
}

class _ChatLoadingBubbleState extends State<ChatLoadingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final phase = (_controller.value + index * 0.2) % 1.0;
                    final scale =
                        0.75 + (phase < 0.5 ? phase : 1 - phase) * 0.9;

                    return Container(
                      width: 10,
                      height: 10,
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(
                          alpha: scale.clamp(0.35, 1.0),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
