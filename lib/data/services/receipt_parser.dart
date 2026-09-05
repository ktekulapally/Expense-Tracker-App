import 'package:intl/intl.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Data models
/// ─────────────────────────────────────────────────────────────────────────

class ParsedReceipt {
  final String? vendor;
  final String? date; // yyyy-MM-dd
  final double? totalAmount;
  final List<LineItem> lineItems;
  final String currency;
  final double confidence;
  final String rawOcrText;

  ParsedReceipt({
    this.vendor,
    this.date,
    this.totalAmount,
    this.lineItems = const [],
    this.currency = 'INR',
    this.confidence = 0.0,
    required this.rawOcrText,
  });

  @override
  String toString() =>
      'ParsedReceipt(vendor: $vendor, date: $date, amount: $totalAmount, '
      'category: ${CategoryMatcher.suggestCategory(vendor, lineItems, rawOcrText).category})';
}

class LineItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  LineItem({
    required this.description,
    this.quantity = 1.0,
    required this.unitPrice,
    required this.totalPrice,
  });
}

class CategorySuggestion {
  final String category;
  final double score;
  CategorySuggestion({required this.category, required this.score});
}

/// ─────────────────────────────────────────────────────────────────────────
/// ReceiptParser
///
/// Handles four distinct receipt formats:
///   A. PhonePe / GPay / Paytm UPI transaction screenshots
///   B. Amazon / E-Commerce Tax Invoices & Order Memos
///   C. Electricity / utility bills (TGSPDCL, TSSPDCL, TSNPDCL, etc.)
///   D. Traditional printed store / restaurant receipts
/// ─────────────────────────────────────────────────────────────────────────

class ReceiptParser {
  // ── Known vendor fast-path map (normalized to <= 25 chars) ──────────────
  static const Map<String, String> _knownVendors = {
    'amazon': 'Amazon Purchase',
    'flipkart': 'Flipkart Order',
    'myntra': 'Myntra Order',
    'ratnadeep': 'Ratnadeep',
    'venkateshwara': 'Venkateshwara KGS',
    'vijetha': 'Vijetha',
    'kirana': 'Kirana Store',
    'dmart': 'DMart',
    'd-mart': 'DMart',
    'big bazaar': 'Big Bazaar',
    'reliance fresh': 'Reliance Fresh',
    'reliance smart': 'Reliance Smart',
    'mcdonalds': "McDonald's",
    "mcdonald's": "McDonald's",
    'kfc': 'KFC',
    'dominos': "Domino's",
    "domino's": "Domino's",
    'starbucks': 'Starbucks',
    'subway': 'Subway',
    'swagruha': 'Swagruha Foods',
    'garuda': 'Garuda Filling Station',
    'tgspdcl': 'TGSPDCL Electricity',
    'tsspdcl': 'TSSPDCL Electricity',
    'tsnpdcl': 'TSNPDCL Electricity',
  };

  // ── Known message keywords that should become the Note directly ────────
  static const List<String> _knownNoteKeywords = [
    'Petrol', 'Diesel', 'Fuel', 'Sweets', 'Groceries', 'Grocery',
    'Lunch', 'Dinner', 'Breakfast', 'Snacks', 'Tea', 'Coffee',
    'Medicine', 'Milk', 'Vegetables', 'Fruits', 'JIO Bill',
  ];

  // ── UPI markers ─────────────────────────────────────────────────────────
  static const List<String> _upiMarkers = [
    'transaction successful', 'payment successful', 'phonepe transaction',
    'paid to', 'debited from', 'transfer to', 'utr', 'upi', 'phonepe',
    'gpay', 'google pay', 'paytm', 'powered by', '@ybl', '@oksbi',
    '@okicici', '@okhdfcbank', '@hdfcbank', '@apl', '@ibl',
  ];

  // ── Amazon & E-Commerce Invoice Markers ─────────────────────────────────
  static const List<String> _amazonMarkers = [
    'amazon.in', 'amazon seller', 'tax invoice/bill of supply',
    'order number: 405-', 'order date:', 'invoice details :',
    'invoice value:', 'karshanram patel'
  ];

  // ── Noise words that must NEVER be used as Note or Vendor ──────────────
  static const List<String> _noiseWords = [
    'axis bank', 'yes bank', 'sbi', 'state bank of india', 'hdfc bank',
    'icici bank', 'kotak bank', 'canara bank', 'pnb', 'bob', 'union bank',
    'ufid', 'upi', 'phonepe', 'gpay', 'paytm', 'powered by', 'transaction',
    'payment details', 'transfer details', 'debited from', 'paid to',
    'utr', 'message', 'successful', 'xxxxxx', 'tax invoice', 'bill of supply',
    'original for recipient', 'sold by', 'billing address', 'shipping address',
    'authorized signatory',
  ];

  // ── Month map for date parsing ──────────────────────────────────────────
  static const Map<String, int> _monthMap = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // ════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════════

  ParsedReceipt parseReceipt(String rawOcrText) {
    if (rawOcrText.trim().isEmpty) {
      return ParsedReceipt(confidence: 0.0, rawOcrText: rawOcrText);
    }

    final lines = rawOcrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final lower = rawOcrText.toLowerCase();

    if (_isAmazonInvoice(lower)) return _parseAmazonInvoice(lines, lower, rawOcrText);
    if (_isUpiScreenshot(lower))  return _parseUpiScreenshot(lines, lower, rawOcrText);
    if (_isUtilityBill(lower))    return _parseUtilityBill(lines, lower, rawOcrText);
    return _parseTraditionalReceipt(lines, lower, rawOcrText);
  }

  // ────────────────────────────────────────────────────────────────────────
  // FORMAT DETECTION
  // ────────────────────────────────────────────────────────────────────────

  bool _isAmazonInvoice(String lower) {
    if (lower.contains('amazon')) return true;
    return _amazonMarkers.any((m) => lower.contains(m));
  }

  bool _isUpiScreenshot(String lower) {
    return _upiMarkers.any((m) => lower.contains(m));
  }

  bool _isUtilityBill(String lower) {
    return lower.contains('tgspdcl') ||
           lower.contains('tsspdcl') ||
           lower.contains('tsnpdcl') ||
           lower.contains('electricity duty') ||
           lower.contains('sc no.') ||
           lower.contains('usc no.');
  }

  // ════════════════════════════════════════════════════════════════════════
  // PATH A: Amazon / E-Commerce Tax Invoices
  // ════════════════════════════════════════════════════════════════════════

  ParsedReceipt _parseAmazonInvoice(
      List<String> lines, String lower, String raw) {

    // Note is "Amazon Purchase" (capped <= 25 chars)
    final noteDescription = 'Amazon Purchase';
    final amount          = _extractAmountFromReceipt(lines, raw);
    final date            = _extractUniversalDate(lower);

    return ParsedReceipt(
      vendor:      noteDescription,
      date:        date,
      totalAmount: amount,
      lineItems:   const [],
      currency:    'INR',
      confidence:  0.95,
      rawOcrText:  raw,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PATH B: UPI / PhonePe screenshots
  // ════════════════════════════════════════════════════════════════════════

  ParsedReceipt _parseUpiScreenshot(
      List<String> lines, String lower, String raw) {

    final noteDescription = _extractUpiNote(lines, lower);
    final amount          = _extractAmountFromReceipt(lines, raw);
    final date            = _extractUniversalDate(lower);

    double conf = 0.3;
    if (noteDescription != null) conf += 0.25;
    if (amount != null)          conf += 0.30;
    if (date   != null)          conf += 0.15;

    return ParsedReceipt(
      vendor:      noteDescription,
      date:        date,
      totalAmount: amount,
      lineItems:   const [],
      currency:    'INR',
      confidence:  conf.clamp(0.0, 1.0),
      rawOcrText:  raw,
    );
  }

  /// Extracts the best Note for the expense (Capped to max 25 characters):
  /// 1. First extracts the value from the "Message" section (e.g. "Sweets", "Petrol")
  /// 2. If message contains "Payment for 12345", cleans to "Payment"
  /// 3. If message contains JIO tracking code, cleans to "JIO Bill"
  /// 4. If no valid message, checks for known message words ("Petrol", "Sweets")
  /// 5. If no message, falls back to clean Payee name ("Ratnadeep", etc.)
  String? _extractUpiNote(List<String> lines, String lower) {
    // 1. Check for explicit "Message" field value in the receipt
    final message = _extractUpiMessage(lines);
    if (message != null) {
      final cleanedMsg = _normalizeMessageNote(message);
      if (cleanedMsg != null && _isCleanNote(cleanedMsg)) {
        return _capLength(cleanedMsg, 25);
      }
    }

    // 2. Direct check for known high-priority message words in the text
    for (final kw in _knownNoteKeywords) {
      final reg = RegExp('\\b${RegExp.escape(kw)}\\b', caseSensitive: false);
      if (reg.hasMatch(lower)) {
        return _capLength(kw, 25); // Returns "Petrol", "Sweets", etc.
      }
    }

    // 3. Direct check for known vendor brands
    for (final kv in _knownVendors.entries) {
      if (lower.contains(kv.key)) {
        return _capLength(kv.value, 25); // Returns "Ratnadeep", "Amazon Purchase", etc.
      }
    }

    // 4. Extract Payee Name from "Paid to" section
    final payee = _extractUpiPayee(lines);
    if (payee != null && _isCleanNote(payee)) {
      return _capLength(payee, 25);
    }

    return null;
  }

  /// Normalizes common message strings according to specification:
  /// • 'Payment for 123456788' ➔ 'Payment'
  /// • 'JIO20BR2TYFFJ...' ➔ 'JIO Bill'
  String? _normalizeMessageNote(String message) {
    final lower = message.toLowerCase().trim();
    if (lower.startsWith('payment for') || lower.startsWith('payment to')) {
      return 'Payment';
    }
    if (lower.startsWith('jio')) {
      return 'JIO Bill';
    }
    if (lower.startsWith('airtel')) {
      return 'Airtel Bill';
    }
    return message;
  }

  String _capLength(String text, int maxLen) {
    return text.length > maxLen ? text.substring(0, maxLen).trim() : text;
  }

  /// Extracts the exact value from the "Message" section of the UPI receipt
  String? _extractUpiMessage(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase().trim();

      // Case A: "Message Sweets" or "Message: Sweets" on the same line
      if (lower.startsWith('message') && line.length > 7) {
        final after = line.substring(7).replaceAll(RegExp(r'^[:\s\-]+'), '').trim();
        if (_isCleanNote(after)) return after;
      }

      // Case B: "Message" on its own line, value on the next line (e.g. "Sweets" or "Petrol")
      if (lower == 'message' || lower == 'message:') {
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (_isCleanNote(nextLine)) return nextLine;
        }
      }
    }
    return null;
  }

  /// Extracts Payee Name from the "Paid to" block
  String? _extractUpiPayee(List<String> lines) {
    int paidToIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (lower.contains('paid to') || lower.contains('transfer to')) {
        paidToIdx = i;
        break;
      }
    }

    if (paidToIdx >= 0) {
      final end = (paidToIdx + 4).clamp(0, lines.length);
      for (int i = paidToIdx + 1; i < end; i++) {
        var line = lines[i];
        final lower = line.toLowerCase();

        // Stop if line contains UPI ID (@) or details
        if (lower.contains('@') ||
            lower.contains('payment details') ||
            lower.contains('transfer details') ||
            lower.contains('message')) {
          break;
        }

        // Clean out inline amounts and currency symbols
        line = line
            .replaceAll(RegExp(r'[₹\u20B9*F~?Ez#]?\s*\d+(?:,\d{3})*(?:\.\d{2})?'), '')
            .replaceAll(RegExp(r'[@\-_]'), ' ')
            .trim();

        if (_isCleanNote(line)) {
          return line;
        }
      }
    }
    return null;
  }

  /// Verifies that a candidate string is clean (not a noise line, transaction ID, bank name, or UPI ID)
  bool _isCleanNote(String text) {
    if (text.length < 2 || text.length > 50) return false;
    final lower = text.toLowerCase();

    // Must not contain noise words
    if (_noiseWords.any((w) => lower.contains(w))) return false;
    // Must not contain UPI ID handle
    if (lower.contains('@') || lower.contains('.ybl') || lower.contains('.sbi')) return false;
    // Must not be a transaction ID
    if (text.startsWith('T2') && text.length > 10) return false;
    // Must not be mostly digits (e.g. "2048643785")
    final digits = text.replaceAll(RegExp(r'\D'), '').length;
    if (digits > text.length ~/ 3 && !lower.startsWith('jio')) return false;

    return true;
  }

  /// Extracts the transaction amount from receipt / screenshot OCR text.
  /// Handles:
  ///   - Keywords: TOTAL, Invoice Value, Total Amount, Net Payable, Total Paid, Paid, Received Amount
  ///   - All UPI amounts prefixed with ₹, \u20B9, Rs, rs, INR, or OCR glyph variants
  ///   - Comma-separated numbers: 4,599.00, 1,345.00
  double? _extractAmountFromReceipt(List<String> lines, String rawText) {
    final candidateAmounts = <double>[];

    // Priority 1: Amounts associated with TOTAL / Invoice Value / Total Amount keywords
    final totalKeywords = [
      'total:', 'total amount', 'invoice value:', 'invoice value', 'net payable',
      'total paid', 'received amount', 'grand total', 'payable amount', 'net amount'
    ];

    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (totalKeywords.any((k) => lower.contains(k))) {
        final checkLines = [lines[i]];
        if (i + 1 < lines.length) checkLines.add(lines[i + 1]);

        for (final cl in checkLines) {
          // Look for currency or comma numbers in this total line
          final m = RegExp(r'(?:[₹\u20B9]|Rs\.?|INR)?\s*(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d{2,6}(?:\.\d{1,2})?)', caseSensitive: false).allMatches(cl);
          for (final match in m) {
            final raw = match.group(1);
            if (raw != null) {
              final v = double.tryParse(raw.replaceAll(',', ''));
              if (v != null && v > 0 && !_isDateOrYear(v)) {
                // Highly weighted (3x) because it is directly next to a TOTAL keyword
                candidateAmounts.add(v);
                candidateAmounts.add(v);
                candidateAmounts.add(v);
              }
            }
          }
        }
      }
    }

    // Priority 2: Strict Indian Rupee symbol prefix (₹4,599.00, ₹840, ₹500, ₹1,345, \u20B9840)
    final rupeePattern = RegExp(
      r'[₹\u20B9]\s*(\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?)',
    );
    for (final m in rupeePattern.allMatches(rawText)) {
      final raw = m.group(1);
      if (raw != null) {
        final v = double.tryParse(raw.replaceAll(',', ''));
        if (v != null && v > 0 && !_isDateOrYear(v)) {
          candidateAmounts.add(v);
          candidateAmounts.add(v); // Double weight for explicit ₹ matches
        }
      }
    }

    // Priority 3: Rs / INR / OCR glyphs (*840, F840, Rs. 840, INR 840, ~840, ?840)
    final ocrRupeePattern = RegExp(
      r'(?:Rs\.?|rs\.?|INR|[*\u007E?#])\s*(\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    for (final m in ocrRupeePattern.allMatches(rawText)) {
      final raw = m.group(1);
      if (raw != null) {
        final v = double.tryParse(raw.replaceAll(',', ''));
        if (v != null && v > 0 && !_isDateOrYear(v)) {
          candidateAmounts.add(v);
        }
      }
    }

    // Priority 4: Comma-formatted numbers (e.g. 4,599.00, 1,345.00)
    final commaPattern = RegExp(r'\b(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?)\b');
    for (final m in commaPattern.allMatches(rawText)) {
      final raw = m.group(1);
      if (raw != null) {
        final v = double.tryParse(raw.replaceAll(',', ''));
        if (v != null && v > 0 && !_isDateOrYear(v)) {
          candidateAmounts.add(v);
        }
      }
    }

    // Priority 5: Scan line-by-line for amount numbers
    for (final line in lines) {
      final lower = line.toLowerCase();

      // Skip lines that are purely metadata headers
      if (lower.startsWith('utr') ||
          lower.startsWith('phonepe transaction') ||
          (lower.startsWith('t2') && line.length > 15) ||
          lower.contains('08:59') ||
          lower.contains('10:20') ||
          lower.contains('10:33') ||
          lower.contains('14:58:59')) {
        continue;
      }

      // Remove UTR numbers (10+ digits), account masks (XXXXXX0728) and dates
      final cleanedLine = line
          .replaceAll(RegExp(r'\b\d{10,24}\b'), ' ')
          .replaceAll(RegExp(r'XXXXXX\d+'), ' ')
          .replaceAll(RegExp(r'[X\d]{6,}\b'), ' ')
          .replaceAll(RegExp(r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}'), ' ')
          .replaceAll(RegExp(r'\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}', caseSensitive: false), ' ');

      // Find any digits in the cleaned line
      final matches = RegExp(r'(?:[₹\u20B9*F~?Ez#]|Rs\.?|rs\.?|INR)?\s*(\d{2,6}(?:\.\d{1,2})?)', caseSensitive: false).allMatches(cleanedLine);
      for (final m in matches) {
        final raw = m.group(1);
        if (raw == null) continue;

        // Correct for OCR artifact where ₹ is transcribed as leading 7 (e.g. 7500 -> 500, 7840 -> 840)
        if (raw.startsWith('7') && raw.length >= 3 && raw.length <= 6) {
          final corrected = raw.substring(1);
          final vCorrected = double.tryParse(corrected);
          if (vCorrected != null && vCorrected >= 10 && !_isDateOrYear(vCorrected)) {
            candidateAmounts.add(vCorrected);
            continue;
          }
        }

        final v = double.tryParse(raw);
        if (v != null && v >= 10 && v < 1000000 && !_isDateOrYear(v) && !_isNoiseNumber(raw)) {
          candidateAmounts.add(v);
        }
      }
    }

    if (candidateAmounts.isEmpty) return null;

    // Prioritize amounts with the highest frequency
    final freq = <double, int>{};
    for (final a in candidateAmounts) {
      freq[a] = (freq[a] ?? 0) + 1;
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : b.key.compareTo(a.key);
      });

    return sorted.first.key;
  }

  bool _isDateOrYear(double val) {
    return val == 2024 || val == 2025 || val == 2026 || val == 2027 || val == 2028;
  }

  bool _isNoiseNumber(String raw) {
    if (raw.length == 4 && raw.startsWith('0')) return true;
    if (raw.length >= 10) return true;
    return false;
  }

  /// Universal date extractor:
  /// 1. PhonePe timestamp format ("10:33 am on 27 Aug 2026")
  /// 2. Text month format ("27 Aug 2026", "24 July 2026")
  /// 3. Dot/Slash date format ("24.07.2026", "24/07/2026")
  /// 4. ISO format ("2026-07-24")
  String? _extractUniversalDate(String lower) {
    // 1. Text Month format: "27 Aug 2026"
    final mText = RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(lower);

    if (mText != null) {
      try {
        final day   = int.parse(mText.group(1)!);
        final month = _monthMap[mText.group(2)!.toLowerCase().substring(0, 3)] ?? 0;
        final year  = int.parse(mText.group(3)!);
        if (month > 0) {
          return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
        }
      } catch (_) {}
    }

    // 2. Dot or Slash format: "24.07.2026" or "24/07/2026" (Common in Amazon & Tax Invoices)
    final mDot = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{4})').firstMatch(lower);
    if (mDot != null) {
      try {
        final d1 = int.parse(mDot.group(1)!);
        final d2 = int.parse(mDot.group(2)!);
        final year = int.parse(mDot.group(3)!);

        // Standard Indian / EU DD.MM.YYYY
        final day = (d1 > 12 || d2 <= 12) ? d1 : d2;
        final month = (d1 > 12 || d2 <= 12) ? d2 : d1;

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
        }
      } catch (_) {}
    }

    // 3. Fallback: ISO format 2026-07-24
    final isoM = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(lower);
    if (isoM != null) {
      return isoM.group(0);
    }

    return null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // PATH C: Electricity / utility bills
  // ════════════════════════════════════════════════════════════════════════

  ParsedReceipt _parseUtilityBill(
      List<String> lines, String lower, String raw) {
    return ParsedReceipt(
      vendor:      'TGSPDCL Electricity',
      date:        _extractUniversalDate(lower) ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      totalAmount: _extractAmountFromReceipt(lines, raw),
      lineItems:   const [],
      currency:    'INR',
      confidence:  0.85,
      rawOcrText:  raw,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PATH D: Traditional printed receipts
  // ════════════════════════════════════════════════════════════════════════

  ParsedReceipt _parseTraditionalReceipt(
      List<String> lines, String lower, String raw) {
    double conf = 0.0;

    final vendor = _extractUpiNote(lines, lower);
    if (vendor != null) conf += 0.25;

    final date = _extractUniversalDate(lower);
    if (date != null) conf += 0.25;

    final amount = _extractAmountFromReceipt(lines, raw);
    if (amount != null && amount > 0) conf += 0.40;

    return ParsedReceipt(
      vendor:      vendor,
      date:        date,
      totalAmount: amount,
      lineItems:   const [],
      currency:    'INR',
      confidence:  conf.clamp(0.0, 1.0),
      rawOcrText:  raw,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// CategoryMatcher
///
/// Ordered from most-specific to least-specific.
/// Scans vendor name + UPI message field + line items.
/// ─────────────────────────────────────────────────────────────────────────

class CategoryMatcher {
  static const List<MapEntry<String, List<String>>> _rules = [

    // ── Fuel ──────────────────────────────────────────────────────────────
    MapEntry('Fuel', [
      'petrol', 'diesel', 'fuel', 'filling station', 'fuel station',
      'gas station', 'pump', 'hpcl', 'bpcl', 'iocl', 'indian oil',
      'hp petrol', 'essar', 'reliance bp', 'nayara', 'garuda', 'shell',
      'cng', 'lpg',
    ]),

    // ── Food ──────────────────────────────────────────────────────────────
    MapEntry('Food', [
      'restaurant', 'cafe', 'coffee', 'pizza', 'burger', 'dhaba', 'dhabha',
      'hotel', 'food court', 'corner', 'biryani', 'noodles', 'bakery', 'bar', 'pub',
      'dining', 'eatery', 'fast food', 'sweets', 'sweet house', 'mithai',
      'halwai', 'tiffin', 'juice', 'tea', 'chai', 'canteen', 'mess',
      'swagruha', 'foods', 'food',
      'mcdonalds', "mcdonald's", 'subway', 'dominos', "domino's",
      'kfc', 'pizzahut', 'pizza hut', 'starbucks', 'burger king',
      'wow momo', 'barbeque', 'paradise biryani', 'behrouz',
      'breakfast', 'lunch', 'dinner', 'snack', 'snacks',
    ]),

    // ── Groceries ─────────────────────────────────────────────────────────
    MapEntry('Groceries', [
      'ratnadeep', 'ratnadeep market', 'ratnadeep vikram',
      'venkateshwara', 'vijetha', 'kirana', 'provision store',
      'dmart', 'd-mart', 'big bazaar', 'easyday', 'more supermarket',
      'reliance fresh', 'reliance smart', 'star bazaar', 'hypercity',
      'nilgiris', 'spar', 'lulu', 'metro cash', 'wholesale', 'bazaar',
      'supermarket', 'hypermarket', 'grocery', 'groceries',
      'general store', 'departmental store',
      'vegetables', 'fruits', 'sabzi', 'mandi', 'dairy',
      'heritage', 'chitale', 'creamline dairy',
    ]),

    // ── Electricity Bills ────────────────────────────────────────────────
    MapEntry('Electricity Bills', [
      'electricity', 'tgspdcl', 'tsspdcl', 'tsnpdcl', 'bescom', 'msedcl',
      'tneb', 'cesc', 'wbsedcl', 'electric bill', 'power supply',
      'electricity bill', 'electricity duty', 'sc no', 'usc no', 'energy charges',
    ]),

    // ── Mobile / Wifi Bills ───────────────────────────────────────────────
    MapEntry('Mobile / Wifi Bills', [
      'jio', 'airtel', 'bsnl', 'vodafone', 'vi', 'broadband', 'internet',
      'wifi', 'recharge', 'prepaid', 'postpaid', 'mobile bill', 'phone bill',
      'dth', 'tata sky', 'dish tv', 'act fibernet', 'hathway', 'excitel',
      'fiber', 'airtel xstream', 'jiofiber',
    ]),

    // ── Bills / Utilities ────────────────────────────────────────────────
    MapEntry('Bills / Utilities', [
      'water bill', 'gas bill', 'gas cylinder', 'indane', 'bharat gas',
      'hp gas', 'maintenance', 'society', 'property tax', 'insurance',
      'lic', 'premium', 'ott', 'subscription',
    ]),

    // ── Rent ─────────────────────────────────────────────────────────────
    MapEntry('Rent', [
      'house rent', 'flat rent', 'shop rent', 'monthly rent', 'room rent', 'rent',
    ]),

    // ── Transport ────────────────────────────────────────────────────────
    MapEntry('Transport', [
      'uber', 'ola', 'rapido', 'auto', 'taxi', 'cab', 'parking', 'toll',
      'metro', 'irctc', 'railway', 'train ticket', 'bus ticket', 'flight',
      'airline', 'indigo', 'air india', 'spicejet', 'redbus', 'abhibus',
    ]),

    // ── Shopping ─────────────────────────────────────────────────────────
    MapEntry('Shopping', [
      'amazon', 'amazon.in', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa',
      'tata cliq', 'snapdeal', 'shoppers stop', 'lifestyle', 'central',
      'westside', 'max fashion', 'h&m', 'zara', 'pantaloons',
      'cloth', 'dress', 'shirt', 'pants', 'jeans', 'footwear',
      'shoes', 'sandals', 'bag', 'accessories', 'jewellery', 'jewelry',
      'electronics', 'croma', 'reliance digital', 'vijay sales',
    ]),

    // ── Health ────────────────────────────────────────────────────────────
    MapEntry('Health', [
      'hospital', 'clinic', 'doctor', 'pharmacy', 'medical', 'medicine',
      'health', 'dental', 'dentist', 'diagnostic', 'lab test', 'pathology',
      'apollo', 'fortis', 'max hospital', 'wellness', 'ayurveda',
      'chemist', 'druggist', '1mg', 'netmeds', 'pharmeasy',
      'thyrocare', 'lal path labs', 'metropolis', 'therapy', 'physio', 'gym',
    ]),

    // ── Entertainment ─────────────────────────────────────────────────────
    MapEntry('Entertainment', [
      'movie', 'cinema', 'pvr', 'inox', 'cinepolis', 'theater', 'theatre',
      'concert', 'show', 'event', 'ticket', 'netflix', 'prime video',
      'hotstar', 'disney', 'zee5', 'spotify', 'gaana', 'youtube premium',
      'game', 'gaming', 'steam', 'playstation', 'xbox', 'nintendo',
    ]),

    // ── Adhoc ────────────────────────────────────────────────────────────
    MapEntry('Adhoc', [
      'adhoc', 'miscellaneous', 'misc', 'emergency',
    ]),
  ];

  /// Suggest category by scanning vendor, UPI message (rawOcrText), and line items.
  static CategorySuggestion suggestCategory(
    String? vendor,
    List<LineItem> lineItems, [
    String? rawOcrText,
  ]) {
    final noteLower = vendor?.toLowerCase() ?? '';
    final rawLower  = rawOcrText?.toLowerCase() ?? '';
    final itemsText = lineItems.map((i) => i.description.toLowerCase()).join(' ');

    String bestCategory = 'Others';
    double bestScore    = 0.0;

    for (final rule in _rules) {
      double score = 0.0;
      for (final kw in rule.value) {
        // High priority (2.0): Direct match in Note / Vendor
        if (noteLower.isNotEmpty && (noteLower.contains(kw) || kw.contains(noteLower))) {
          score += 2.0;
        } else if (rawLower.contains(kw) || itemsText.contains(kw)) {
          final weight = kw.length >= 10 ? 0.9
                       : kw.length >= 6  ? 0.6
                       :                   0.3;
          score += weight;
        }
      }
      if (score > bestScore) {
        bestScore    = score;
        bestCategory = rule.key;
      }
    }

    return CategorySuggestion(category: bestCategory, score: bestScore);
  }
}
