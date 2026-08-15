import 'dart:math';
import 'package:intl/intl.dart';

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
  String toString() {
    return 'ParsedReceipt(vendor: $vendor, date: $date, totalAmount: $totalAmount, category: ${CategoryMatcher.suggestCategory(vendor, lineItems).category}, confidence: $confidence)';
  }
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

class ReceiptParser {
  // Regex patterns
  static final RegExp _amountPattern = RegExp(
    r'(?:₹|Rs\.?|INR)\s*(\d+(?:[,\.]\d{2,3})*(?:\.\d{2})?)',
    caseSensitive: false,
  );

  static final List<RegExp> _datePatterns = [
    // Pattern 0: Text date format (e.g., 15 Aug, 2026 or 15 August 2026)
    RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*,?\s+(\d{2,4})',
      caseSensitive: false,
    ),
    // Pattern 1: YYYY/MM/DD or YYYY-MM-DD
    RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})'),
    // Pattern 2: DD/MM/YYYY or MM/DD/YYYY
    RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})'),
  ];

  static const Map<String, int> _monthMap = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
  };

  static const Map<String, String> _knownVendors = {
    'mcdonalds': "McDonald's",
    'mcdonald\'s': "McDonald's",
    'subway': 'Subway',
    'dominos': 'Domino\'s',
    'domino\'s': 'Domino\'s',
    'kfc': 'KFC',
    'pizzahut': 'Pizza Hut',
    'pizza hut': 'Pizza Hut',
    'starbucks': 'Starbucks',
    'uber': 'Uber',
    'ola': 'Ola',
    'amazon': 'Amazon',
    'walmart': 'Walmart',
    'ikea': 'IKEA',
    'reliance': 'Reliance',
    'big bazaar': 'Big Bazaar',
    'dmart': 'DMart',
    'lassi story': 'Lassi Story',
  };

  static const Set<String> _receiptHeaders = {
    'receipt', 'invoice', 'bill', 'transaction', 'order',
    'thank you', 'thank u', 'visit us', 'follow us',
    'customer care', 'help', 'dine in'
  };

  static const Set<String> _excludeLineKeywords = {
    'total', 'subtotal', 'sub-total', 'tax', 'gst', 'cgst', 'sgst', 'vat',
    'discount', 'disc', 'payment', 'cash', 'card', 'change', 'balance',
    'due', 'amount', 'net', 'gross', 'rounding', 'round off', 'service charge',
    'visa', 'mastercard', 'amex', 'upi', 'paytm', 'gpay', 'phonepe',
    'mobile', 'phone', 'tel', 'email', 'address', 'website', 'cashier'
  };

  ParsedReceipt parseReceipt(String rawOcrText) {
    if (rawOcrText.trim().isEmpty) {
      return ParsedReceipt(confidence: 0.0, rawOcrText: rawOcrText);
    }

    final lines = rawOcrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double confidence = 0.0;
    String? vendorName;
    String? dateFound;
    double? totalAmount;

    // 1. Extract Vendor Name
    vendorName = _extractVendor(lines);
    if (vendorName != null) confidence += 0.25;

    // 2. Extract Date
    dateFound = _extractDate(lines);
    if (dateFound != null) confidence += 0.25;

    // 3. Extract Total Amount
    totalAmount = _extractTotalAmount(lines);
    if (totalAmount != null && totalAmount > 0) confidence += 0.40;

    // 4. Extract Line Items
    final lineItems = _extractLineItems(lines);
    if (lineItems.isNotEmpty) confidence += 0.10;

    confidence = confidence.clamp(0.0, 1.0);

    return ParsedReceipt(
      vendor: vendorName,
      date: dateFound,
      totalAmount: totalAmount,
      lineItems: lineItems,
      currency: 'INR',
      confidence: confidence,
      rawOcrText: rawOcrText,
    );
  }

  String? _extractVendor(List<String> lines) {
    final allText = lines.join(' ').toLowerCase();

    // Check high-priority known vendors in entire text
    for (var entry in _knownVendors.entries) {
      final regExp = RegExp('\\b${RegExp.escape(entry.key)}\\b', caseSensitive: false);
      if (regExp.hasMatch(allText)) {
        return entry.value;
      }
    }

    // Fallback to first few non-header lines
    for (var line in lines.take(8)) {
      final cleaned = line.trim().toLowerCase();
      if (_receiptHeaders.any((h) => cleaned.contains(h))) continue;
      if (cleaned.length < 3) continue;

      // Skip contact information
      if (cleaned.contains('email') ||
          cleaned.contains('phone') ||
          cleaned.contains('tel') ||
          cleaned.contains('mobile') ||
          cleaned.contains('road') ||
          cleaned.contains('nagar') ||
          cleaned.contains('street') ||
          cleaned.contains('hyderabad')) {
        continue;
      }

      // Check digit ratio to avoid lines that are mostly metadata
      final digits = line.replaceAll(RegExp(r'\D'), '');
      if (digits.length > 4) continue;

      return line.trim();
    }

    return null;
  }

  String? _extractDate(List<String> lines) {
    final allText = lines.join(' ');

    // 1. Try text pattern (e.g. 15 Aug, 2026)
    final textMatch = _datePatterns[0].firstMatch(allText);
    if (textMatch != null) {
      try {
        final day = int.parse(textMatch.group(1)!);
        final monthStr = textMatch.group(2)!.toLowerCase();
        final month = _monthMap[monthStr] ?? 1;
        var yearVal = int.parse(textMatch.group(3)!);
        final year = yearVal < 100 ? 2000 + yearVal : yearVal;

        final dateObj = DateTime(year, month, day);
        return DateFormat('yyyy-MM-dd').format(dateObj);
      } catch (_) {}
    }

    // 2. Try YYYY/MM/DD pattern
    final yyyyMatch = _datePatterns[1].firstMatch(allText);
    if (yyyyMatch != null) {
      try {
        final year = int.parse(yyyyMatch.group(1)!);
        final month = int.parse(yyyyMatch.group(2)!);
        final day = int.parse(yyyyMatch.group(3)!);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final dateObj = DateTime(year, month, day);
          return DateFormat('yyyy-MM-dd').format(dateObj);
        }
      } catch (_) {}
    }

    // 3. Try DD/MM/YYYY or MM/DD/YYYY pattern
    final ddMatch = _datePatterns[2].firstMatch(allText);
    if (ddMatch != null) {
      try {
        final val1 = int.parse(ddMatch.group(1)!);
        final val2 = int.parse(ddMatch.group(2)!);
        var yearVal = int.parse(ddMatch.group(3)!);
        final year = yearVal < 100 ? 2000 + yearVal : yearVal;

        int day = val1;
        int month = val2;

        if (val1 > 12 && val2 <= 12) {
          day = val1;
          month = val2;
        } else if (val2 > 12 && val1 <= 12) {
          day = val2;
          month = val1;
        }

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final dateObj = DateTime(year, month, day);
          return DateFormat('yyyy-MM-dd').format(dateObj);
        }
      } catch (_) {}
    }

    return null;
  }

  double? _extractTotalAmount(List<String> lines) {
    final List<double> amounts = [];

    // Look for lines containing "total" or "grand total" or "payable"
    final totalKeywords = [
      'total',
      'grand total',
      'bill amount',
      'net amount',
      'payable',
      'amount due',
      'grandtotal',
      'paid'
    ];

    final genericAmountPattern = RegExp(
      r'(?:₹|Rs\.?|INR)?\s*(\d+(?:[,\.]\d{2,3})*(?:\.\d{2}))',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();

      if (totalKeywords.any((k) => lowerLine.contains(k))) {
        // Collect candidate lines to search: the current line, next line, and previous line
        final candidates = [line];
        if (i + 1 < lines.length) candidates.add(lines[i + 1]);
        if (i - 1 >= 0) candidates.add(lines[i - 1]);

        for (var cand in candidates) {
          // Exclude dates like "15 Aug, 2026" or time "19:41" from being matched as amount
          final dateRegex = RegExp(r'\d{1,4}[./-]\d{1,2}[./-]\d{2,4}');
          final textDateRegex = RegExp(
            r'\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*,?\s+\d{2,4}',
            caseSensitive: false,
          );
          final timeRegex = RegExp(r'\d{1,2}:\d{2}');

          final cleanedCand = cand
              .replaceAll(dateRegex, ' ')
              .replaceAll(textDateRegex, ' ')
              .replaceAll(timeRegex, ' ');

          final matches = genericAmountPattern.allMatches(cleanedCand);
          for (var match in matches) {
            try {
              final amtStr = match.group(1)!.replaceAll(',', '');
              final val = double.parse(amtStr);
              // Avoid returning years or invoices as totals
              if (val != 2026 && val != 2025 && val != 2027) {
                amounts.add(val);
              }
            } catch (_) {}
          }
        }
      }
    }

    if (amounts.isNotEmpty) {
      // Return the maximum amount found near the total keywords (usually the grand total)
      return amounts.reduce(max);
    }

    // Fallback: search for any currency patterns in the whole receipt
    for (var line in lines) {
      final matches = _amountPattern.allMatches(line);
      for (var match in matches) {
        try {
          final amtStr = match.group(1)!.replaceAll(',', '');
          amounts.add(double.parse(amtStr));
        } catch (_) {}
      }
    }

    if (amounts.isNotEmpty) {
      return amounts.reduce(max);
    }

    return null;
  }

  List<LineItem> _extractLineItems(List<String> lines) {
    final List<LineItem> items = [];
    final genericNumberPattern = RegExp(r'(?:₹|Rs\.?|INR)?\s*(\d+(?:[.,]\d{3})*(?:\.\d{2})?)');

    for (var line in lines) {
      final lowerLine = line.toLowerCase();
      if (line.length < 4) continue;
      if (_receiptHeaders.any((h) => lowerLine.contains(h))) continue;
      if (_excludeLineKeywords.any((k) => lowerLine.contains(k))) continue;
      if (!line.contains(RegExp(r'[a-zA-Z]'))) continue; // Must contain letters

      final matches = genericNumberPattern.allMatches(line).toList();
      if (matches.isNotEmpty) {
        // Description is usually text before the first number or between first and last numbers
        String description = '';
        if (matches.length > 1 && matches.first.start == 0) {
          description = line.substring(matches.first.end, matches.last.start).trim();
        } else {
          description = line.substring(0, matches.first.start).trim();
        }

        // Clean up leading numbers or punctuation in description
        description = description.replaceFirst(RegExp(r'^[-\d.\s+*]+'), '').trim();

        if (description.length >= 3 && description.length < 60) {
          try {
            final totalPrice = double.parse(matches.last.group(1)!.replaceAll(',', ''));
            double quantity = 1.0;
            double unitPrice = totalPrice;

            if (matches.length > 1) {
              final firstAmt = double.parse(matches.first.group(1)!.replaceAll(',', ''));
              if (firstAmt <= 10.0) {
                quantity = firstAmt;
                unitPrice = totalPrice / quantity;
              } else {
                unitPrice = firstAmt;
              }
            }

            items.add(LineItem(
              description: description,
              quantity: quantity,
              unitPrice: unitPrice,
              totalPrice: totalPrice,
            ));
          } catch (_) {}
        }
      }
    }

    return items;
  }
}

class CategoryMatcher {
  static const Map<String, List<String>> _categoryKeywords = {
    'Food': [
      'restaurant', 'cafe', 'coffee', 'pizza', 'burger', 'dhabha', 'hotel',
      'biryani', 'lassi', 'story', 'sweet', 'kulfi', 'ice cream', 'cream',
      'chocolate', 'dining', 'bakery', 'food', 'caterer', 'mcdonald', 'subway',
      'kfc', 'domino', 'starbuck'
    ],
    'Groceries': [
      'supermarket', 'grocery', 'market', 'bazaar', 'vegetables', 'fruits',
      'dmart', 'big bazaar', ' kirana', 'reliance', 'mart'
    ],
    'Fuel': ['petrol', 'diesel', 'gas station', 'fuel', 'hpcl', 'iocl', 'bpcl'],
    'Utilities': [
      'electricity', 'tgspdcl', 'tsspdcl', 'water', 'internet', 'broadband',
      'wifi', 'telecom', 'mobile', 'recharge', 'prepaid', 'postpaid', 'bill'
    ],
    'Rent': ['rent', 'tenant', 'landlord', 'housing'],
    'Entertainment': [
      'movie', 'cinema', 'theater', 'game', 'xbox', 'playstation', 'netflix',
      'spotify', 'ticket'
    ],
    'Adhoc': ['adhoc', 'temp', 'cash', 'misc'],
    'Salary': ['salary', 'wage', 'bonus', 'dividend'],
  };

  static CategorySuggestion suggestCategory(String? vendor, List<LineItem> lineItems) {
    String bestCategory = 'Others';
    double bestScore = 0.0;

    // 1. Scan vendor name
    if (vendor != null && vendor.isNotEmpty) {
      final vendorLower = vendor.toLowerCase();
      for (var entry in _categoryKeywords.entries) {
        final matches = entry.value.where((kw) => vendorLower.contains(kw)).length;
        if (matches > 0) {
          final score = 0.5 + (matches * 0.1).clamp(0.0, 0.4);
          if (score > bestScore) {
            bestScore = score;
            bestCategory = entry.key;
          }
        }
      }
    }

    // 2. Scan line items if score is not high
    if (bestScore < 0.6 && lineItems.isNotEmpty) {
      final allDescriptions = lineItems.map((item) => item.description.toLowerCase()).join(' ');
      for (var entry in _categoryKeywords.entries) {
        final matches = entry.value.where((kw) => allDescriptions.contains(kw)).length;
        if (matches > 0) {
          final score = 0.3 + (matches * 0.05).clamp(0.0, 0.3);
          if (score > bestScore) {
            bestScore = score;
            bestCategory = entry.key;
          }
        }
      }
    }

    return CategorySuggestion(category: bestCategory, score: bestScore);
  }
}

class CategorySuggestion {
  final String category;
  final double score;

  CategorySuggestion({required this.category, required this.score});
}
