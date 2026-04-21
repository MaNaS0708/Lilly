import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  TextRecognitionService()
      : _latinRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        ),
        _devanagiriRecognizer = TextRecognizer(
          script: TextRecognitionScript.devanagiri,
        );

  final TextRecognizer _latinRecognizer;
  final TextRecognizer _devanagiriRecognizer;

  Future<String> extractTextFromFile(String path) async {
    final image = InputImage.fromFilePath(path);

    final latinResult = await _latinRecognizer.processImage(image);
    final latinText = latinResult.text.trim();
    if (latinText.isNotEmpty) {
      return latinText;
    }

    final devanagiriResult = await _devanagiriRecognizer.processImage(image);
    return devanagiriResult.text.trim();
  }

  Future<void> dispose() async {
    await _latinRecognizer.close();
    await _devanagiriRecognizer.close();
  }
}
