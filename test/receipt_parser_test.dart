import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ledger_app/data/services/receipt_parser.dart';

void main() {
  group('ReceiptParser Tests', () {
    final parser = ReceiptParser();

    test('should parse Lassi Story receipt text correctly', () {
      const rawOcrText = """
Lassi Story
Mayuri Nagar, Hyderabad.
Dine In
15 Aug, 2026 19:41
Token# 24
Invoice# 262703995
KOT# 24
Qty Items Amount
2 Death By Chocolate Ice ₹240.00
Cream
1 Sweet Lassi ₹50.00
2 Kulfi ₹100.00
Bill Summary
Item Total ₹390.00
Grand Total ₹390.00
Paid ₹390.00
Balance ₹0.00
THANK YOU & VISIT AGAIN
""";

      final parsed = parser.parseReceipt(rawOcrText);

      expect(parsed.vendor, equals('Lassi Story'));
      expect(parsed.date, equals('2026-08-15'));
      expect(parsed.totalAmount, equals(390.00));

      final categorySuggestion = CategoryMatcher.suggestCategory(parsed.vendor, parsed.lineItems);
      expect(categorySuggestion.category, equals('Food'));
    });
  });
}
