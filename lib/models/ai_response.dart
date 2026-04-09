class AiResponse {
  final String text;
  final bool success;
  final String? errorMessage;

  const AiResponse({
    required this.text,
    required this.success,
    this.errorMessage,
  });

  const AiResponse.success({
    required this.text,
  }) : success = true,
       errorMessage = null;

  const AiResponse.failure({
    required this.errorMessage,
  }) : success = false,
       text = '';
}
