import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser.dart';

class OCRService {
  final ImagePicker _picker = ImagePicker();
  final ReceiptParser _parser = ReceiptParser();

  Future<ParsedReceipt?> pickAndParseReceipt(bool fromCamera) async {
    final XFile? imageFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (imageFile == null) return null;

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      // Release resources
      await textRecognizer.close();

      return _parser.parseReceipt(rawText);
    } catch (e) {
      await textRecognizer.close();
      rethrow;
    }
  }
}
