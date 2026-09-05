import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser.dart';
import 'gemini_receipt_service.dart';

class OCRService {
  final ImagePicker _picker = ImagePicker();
  final ReceiptParser _localParser = ReceiptParser();
  final GeminiReceiptService _geminiService = GeminiReceiptService();

  Future<ParsedReceipt?> pickAndParseReceipt(bool fromCamera) async {
    final XFile? imageFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (imageFile == null) return null;

    // 1. Try Gemini Flash Vision first (if API key is available and device is online)
    try {
      final geminiResult = await _geminiService.parseReceiptWithGemini(imageFile.path);
      if (geminiResult != null && geminiResult.totalAmount != null) {
        debugPrint('Receipt parsed successfully via Gemini Flash Vision.');
        return geminiResult;
      }
    } catch (e) {
      debugPrint('Gemini Vision attempt failed, using local OCR fallback: $e');
    }

    // 2. Fallback: Local Google ML Kit Text Recognition + ReceiptParser
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      // Release resources
      await textRecognizer.close();

      return _localParser.parseReceipt(rawText);
    } catch (e) {
      await textRecognizer.close();
      rethrow;
    }
  }
}
