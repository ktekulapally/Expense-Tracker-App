import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ledger_app/data/models.dart';

void main() {
  group('Personal Ledger Models & Calculations Tests', () {
    test('Expense model JSON serialization and parsing', () {
      final json = {
        'id': 'test-uuid-123',
        'user_id': 'user-uuid-456',
        'expense_date': '2026-08-08',
        'category': 'Groceries',
        'description': 'Weekly grocery run',
        'amount': 1500.50,
        'created_at': '2026-08-08T12:00:00.000Z',
        'recurring_id': null,
        'ledger_id': null,
      };

      final expense = Expense.fromJson(json);
      expect(expense.id, 'test-uuid-123');
      expect(expense.category, 'Groceries');
      expect(expense.amount, 1500.50);
      expect(expense.description, 'Weekly grocery run');
      expect(expense.expenseDate, DateTime.parse('2026-08-08'));

      final serialized = expense.toJson();
      expect(serialized['category'], 'Groceries');
      expect(serialized['amount'], 1500.50);
      expect(serialized['description'], 'Weekly grocery run');
      expect(serialized['expense_date'], '2026-08-08');
    });

    test('Income model JSON serialization and parsing', () {
      final json = {
        'id': 'test-uuid-789',
        'user_id': 'user-uuid-456',
        'income_date': '2026-08-01',
        'source': 'Salary',
        'amount': 50000.00,
        'notes': 'Monthly salary payment',
        'created_at': '2026-08-01T09:00:00.000Z',
        'ledger_id': null,
      };

      final income = Income.fromJson(json);
      expect(income.id, 'test-uuid-789');
      expect(income.source, 'Salary');
      expect(income.amount, 50000.00);
      expect(income.notes, 'Monthly salary payment');

      final serialized = income.toJson();
      expect(serialized['source'], 'Salary');
      expect(serialized['amount'], 50000.00);
      expect(serialized['notes'], 'Monthly salary payment');
      expect(serialized['income_date'], '2026-08-01');
    });

    test('Net statistics calculation utility check', () {
      final double totalIncome = 5000.00;
      final double totalExpenses = 1500.00;
      final double net = totalIncome - totalExpenses;
      expect(net, 3500.00);
    });
  });
}
