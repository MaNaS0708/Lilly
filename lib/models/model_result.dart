class ModelResult {
  final bool success;
  final String text;
  final String? errorMessage;

  const ModelResult({
    required this.success,
    required this.text,
    this.errorMessage,
  });

  const ModelResult.success({
    required this.text,
  }) : success = true,
       errorMessage = null;

  const ModelResult.failure({
    required this.errorMessage,
  }) : success = false,
       text = '';
}
