import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ledger_app/data/services/receipt_parser.dart';

void main() {
  group('ReceiptParser Comprehensive Tests (Amazon, PhonePe, Specification)', () {
    final parser = ReceiptParser();

    test('1. Parses Amazon Tax Invoice (media_1787823825237.jpg)', () {
      const ocrText = '''
amazon.in
Tax Invoice/Bill of Supply/Cash Memo
(Original for Recipient)
Sold By:
KARSHANRAM PATEL
GMR Airport City, Shamshabad
PAN No: BEDPP6338E
GST Registration No: 36BEDPP6338E1ZG
Order Number: 405-1969691-7637938
Order Date: 24.07.2026
Invoice Number: HYD8-1533
Invoice Date : 24.07.2026
Description | Net Amount | Tax Amount | Total Amount
A1TECH 256GB NVMe M.2 SSD | 3,897.46 | 701.54 | 4,599.00
TOTAL:
₹4,599.00
Amount in Words: Four Thousand Five Hundred Ninety-nine only
For KARSHANRAM PATEL:
Authorized Signatory
Payment Transaction ID: TA9oCk4fgy4RqHziYxdM
Date & Time: 24/07/2026, 14:58:59 hrs
Invoice Value: 4,599.00
Mode of Payment: Credit Card
''';

      final parsed = parser.parseReceipt(ocrText);
      expect(parsed.totalAmount, 4599.0);
      expect(parsed.vendor, 'Amazon Purchase');
      expect(parsed.date, '2026-07-24');
      final suggestion = CategoryMatcher.suggestCategory(parsed.vendor, parsed.lineItems, parsed.rawOcrText);
      expect(suggestion.category, 'Shopping');
    });

    test('2. Parses Garuda Fuel filling station (Petrol, ₹500)', () {
      const ocrText = '''
Transaction Successful
08:59 am on 27 Aug 2026
Paid to
PUMP 4 garuda filling station 7500
Q343829082@ybl
Payment Details
Message
Petrol
PhonePe Transaction ID
T2608270859380271823988
Debited from
XXXXXX0728 7500
UTR: 111265842566
Powered by
UPI AXIS BANK
''';

      final parsed = parser.parseReceipt(ocrText);
      expect(parsed.totalAmount, 500.0);
      expect(parsed.vendor, 'Petrol');
      expect(parsed.date, '2026-08-27');
      final suggestion = CategoryMatcher.suggestCategory(parsed.vendor, parsed.lineItems, parsed.rawOcrText);
      expect(suggestion.category, 'Fuel');
    });

    test('3. Parses Ratnadeep groceries (₹1,345)', () {
      const ocrText = '''
Transaction Successful
10:20 am on 27 Aug 2026
Paid to
RATNADEEP 1345
RATNADEEPVIKRAMPU
RI@ybl
Payment Details
Message
Payment for 2048643785
PhonePe Transaction ID
T2608271020278907871855
Debited from
XXXXXX0728 1345
UTR: 888342618176
Powered by
UPI YES BANK
''';

      final parsed = parser.parseReceipt(ocrText);
      expect(parsed.totalAmount, 1345.0);
      expect(parsed.vendor, 'Ratnadeep');
      expect(parsed.date, '2026-08-27');
      final suggestion = CategoryMatcher.suggestCategory(parsed.vendor, parsed.lineItems, parsed.rawOcrText);
      expect(suggestion.category, 'Groceries');
    });

    test('4. Parses Sri Saipriya Swagruha Foods (Sweets, ₹840)', () {
      const ocrText = '''
Transaction Successful
10:33 am on 27 Aug 2026
Paid to
SRI SAIPRIYA SWAGRUHA FOODS 7840
Vyapar.176885146890@hdfcbank
Transfer Details
Message
Sweets
PhonePe Transaction ID
T2608271033283465522828
Debited from
XXXXXX0728 7840
UTR: 032892242581
Powered by
UPI YES BANK
''';

      final parsed = parser.parseReceipt(ocrText);
      expect(parsed.totalAmount, 840.0);
      expect(parsed.vendor, 'Sweets');
      expect(parsed.date, '2026-08-27');
      final suggestion = CategoryMatcher.suggestCategory(parsed.vendor, parsed.lineItems, parsed.rawOcrText);
      expect(suggestion.category, 'Food');
    });

    test('5. Parses Updated Specification rules (Venkateshwara KGS, Vijetha, JIO Bill)', () {
      const ocrText1 = '''
Transaction Successful
Paid to
Venkateshwara KGS
Message
JIO20BR2TYFFJCNFNGNFFNFN
₹750.00
''';
      final parsed1 = parser.parseReceipt(ocrText1);
      expect(parsed1.vendor, 'JIO Bill');
      expect(parsed1.totalAmount, 750.0);
      final sug1 = CategoryMatcher.suggestCategory(parsed1.vendor, parsed1.lineItems, parsed1.rawOcrText);
      expect(sug1.category, 'Mobile / Wifi Bills');

      const ocrText2 = '''
Paid to
Vijetha Supermarket
Total Amount: Rs 1,234.00
''';
      final parsed2 = parser.parseReceipt(ocrText2);
      expect(parsed2.totalAmount, 1234.0);
      final sug2 = CategoryMatcher.suggestCategory(parsed2.vendor, parsed2.lineItems, parsed2.rawOcrText);
      expect(sug2.category, 'Groceries');
    });

    test('6. Parses Electricity and Mobile recharge receipts', () {
      const ocrAirtel = '''
Transaction Successful
Paid to
Airtel Prepaid Recharge
Message
Mobile Recharge 9876543210
₹299.00
''';
      final parsedAirtel = parser.parseReceipt(ocrAirtel);
      final sugAirtel = CategoryMatcher.suggestCategory(parsedAirtel.vendor, parsedAirtel.lineItems, parsedAirtel.rawOcrText);
      expect(sugAirtel.category, 'Mobile / Wifi Bills');

      const ocrPower = '''
TGSPDCL Electricity Bill
SC No: 12345
Net Payable: ₹1,540.00
''';
      final parsedPower = parser.parseReceipt(ocrPower);
      final sugPower = CategoryMatcher.suggestCategory(parsedPower.vendor, parsedPower.lineItems, parsedPower.rawOcrText);
      expect(sugPower.category, 'Electricity Bills');
    });
  });
}
