import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'receipt_parser.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// GeminiReceiptService
///
/// Integrates Google Gemini Flash Vision API for automatic, highly-accurate
/// receipt, UPI screenshot, and tax invoice parsing.
///
/// Features:
///   • Direct image multimodal analysis with Gemini 3.5 / 3.6 Flash
///   • JSON mode structured extraction (amount, date, note, category)
///   • Strict mapping to the app's 13 daily expense categories
///   • Graceful fallback to local OCR regex parser if offline or API key absent
/// ─────────────────────────────────────────────────────────────────────────

class GeminiReceiptService {
  static String apiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const List<String> _models = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const List<String> allowedCategories = [
    'Groceries',
    'Food',
    'Fuel',
    'Electricity Bills',
    'Mobile / Wifi Bills',
    'Shopping',
    'Transport',
    'Health',
    'Bills / Utilities',
    'Rent',
    'Entertainment',
    'Adhoc',
    'Others'
  ];

  /// Parses a receipt / invoice image file using Gemini Flash Vision.
  /// Returns a [ParsedReceipt] on success, or `null` to trigger local fallback.
  Future<ParsedReceipt?> parseReceiptWithGemini(String imagePath, [String? ocrFallbackText]) async {
    if (apiKey.trim().isEmpty) {
      debugPrint('Gemini API key is empty. Falling back to local OCR parser.');
      return null;
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(imagePath);

      final prompt = '''
You are an intelligent financial ledger and receipt parser assistant.
Analyze this receipt / invoice / UPI payment screenshot image and extract 4 structured fields.

ALLOWED CATEGORIES (Pick EXACTLY one):
- Groceries (Supermarkets, Vegetables, Fruits, Milk, Kirana, Ratnadeep, DMart, Vijetha)
- Food (Restaurants, Swagruha Foods, Sweets, Cafes, Biryani, Food Courts, Dining)
- Fuel (Petrol, Diesel, CNG, Garuda, Indian Oil, HPCL, BPCL, Shell)
- Electricity Bills (TGSPDCL, TSSPDCL, TSNPDCL, Electricity Duty, Power Supply)
- Mobile / Wifi Bills (JIO, Airtel, BSNL, Vodafone, VI, Broadband, Wi-Fi, Recharges)
- Shopping (Amazon, Flipkart, Myntra, Clothing, Footwear, Electronics, Hardware)
- Transport (Uber, Ola, Rapido, Metro, Train Tickets, Bus Tickets, Parking, Tolls)
- Health (Pharmacy, Medicines, Apollo, MedPlus, Clinics, Doctors, Hospitals)
- Bills / Utilities (Water Bills, Gas/LPG Cylinders, Maintenance, Insurance, LIC)
- Rent (House Rent, Flat Rent, Shop Rent)
- Entertainment (Movies, PVR, Inox, Netflix, Spotify, Gaming)
- Adhoc (Miscellaneous, One-time expenses)
- Others

EXTRACTION RULES:
1. "amount": The final total / paid / invoice amount as a numeric float/double (e.g. 4599.00, 500.00, 840.00, 1345.00). Must NOT be 0 unless free.
2. "date": Date of transaction in "YYYY-MM-DD" format.
3. "note": Clean, concise label (MAX 25 characters).
   - If Electricity Bill (e.g. TGSPDCL, TSSPDCL, TSNPDCL), use the clean provider name like "TGSPDCL".
   - If UPI Message is present (e.g. "Petrol", "Sweets"), use it!
   - If Amazon/E-commerce, use "Amazon Purchase".
   - If merchant payee (e.g. "Ratnadeep"), use the clean brand name.
   - NEVER include bank names (e.g. Axis Bank), technical UPI handles (@ybl), or masked account numbers.
4. "category": Must be one of the Allowed Categories list above.

Return ONLY a valid JSON object matching this schema:
{
  "amount": 4599.00,
  "date": "2026-07-24",
  "note": "Amazon Purchase",
  "category": "Shopping"
}
''';

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  "mime_type": mimeType,
                  "data": base64Image,
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "response_mime_type": "application/json",
          "temperature": 0.1,
        }
      };

      for (final model in _models) {
        final url = Uri.parse('$_baseUrl/$model:generateContent?key=$apiKey');
        try {
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final jsonText = parts[0]['text'] as String?;
                if (jsonText != null) {
                  return _parseGeminiJsonResponse(jsonText, ocrFallbackText ?? '');
                }
              }
            }
          } else {
            debugPrint('Gemini API ($model) status: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Gemini ($model) attempt error: $e');
        }
      }
    } catch (e) {
      debugPrint('Gemini parsing exception: $e');
    }

    return null;
  }

  ParsedReceipt? _parseGeminiJsonResponse(String jsonString, String rawText) {
    try {
      final cleanJson = jsonString
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final map = jsonDecode(cleanJson) as Map<String, dynamic>;

      final rawAmount = map['amount'];
      double? amount;
      if (rawAmount is num) {
        amount = rawAmount.toDouble();
      } else if (rawAmount is String) {
        amount = double.tryParse(rawAmount.replaceAll(',', '').replaceAll('₹', ''));
      }

      final date = map['date'] as String?;
      final note = map['note'] as String?;
      var category = map['category'] as String? ?? 'Others';

      // Validate category against allowed list
      if (!allowedCategories.contains(category)) {
        final match = allowedCategories.firstWhere(
          (c) => c.toLowerCase() == category.toLowerCase(),
          orElse: () => 'Others',
        );
        category = match;
      }

      return ParsedReceipt(
        vendor: note,
        date: date,
        totalAmount: amount,
        lineItems: const [],
        currency: 'INR',
        confidence: 0.98,
        rawOcrText: rawText.isNotEmpty ? rawText : 'Parsed via Gemini Flash Vision',
      );
    } catch (e) {
      debugPrint('Error parsing Gemini JSON response: $e');
      return null;
    }
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
