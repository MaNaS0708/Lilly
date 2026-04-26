import 'package:flutter/material.dart';

class EmptyChatState extends StatelessWidget {
  const EmptyChatState({
    super.key,
    this.isModelLoading = false,
    this.modelStatusLabel,
  });

  final bool isModelLoading;
  final String? modelStatusLabel;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF473241);
    const muted = Color(0xFF776470);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/lilly_logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Talk to Lilly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isModelLoading
                    ? (modelStatusLabel ?? 'Loading Lilly on your device...')
                    : 'Ask a question, speak naturally, or say “what’s in front of me” to let Lilly read visible text around you.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: muted,
                ),
              ),
              if (isModelLoading) ...[
                const SizedBox(height: 18),
                const CircularProgressIndicator(
                  color: Color(0xFFC88298),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
