import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Raw text from an image file (on-device ML Kit OCR).
  Future<String> extractRawText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  /// Raw text from a live camera frame.
  Future<String> extractFromInputImage(InputImage image) async {
    final RecognizedText result = await _recognizer.processImage(image);
    return result.text;
  }

  /// Full result (blocks + lines) from a live camera frame.
  Future<RecognizedText> recognize(InputImage image) => _recognizer.processImage(image);

  void dispose() {
    _recognizer.close();
  }
}