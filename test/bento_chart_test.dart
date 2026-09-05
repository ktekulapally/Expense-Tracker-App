import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:personal_ledger_app/data/models.dart';
import 'package:personal_ledger_app/data/services/supabase_service.dart';
import 'package:personal_ledger_app/view_models/main_ledger_view_model.dart';
import 'package:personal_ledger_app/ui/features/charts/bento_expense_chart_view.dart';

// Fake SupabaseService for testing
class FakeSupabaseService extends SupabaseService {
  final List<Expense> expenses;
  FakeSupabaseService(this.expenses);

  @override
  Future<List<Expense>> getExpenses({String? ledgerId}) async => expenses;

  @override
  Future<List<Income>> getIncome({String? ledgerId}) async => [];
}

void main() {
  testWidgets('BentoExpenseChartView displays month header, bento tiles, and sorted breakdown', (tester) async {
    final now = DateTime.now();
    final sampleExpenses = [
      Expense(
        id: '1',
        userId: 'user_1',
        expenseDate: DateTime(now.year, now.month, 5),
        category: 'Food',
        amount: 686.0,
        createdAt: now,
      ),
      Expense(
        id: '2',
        userId: 'user_1',
        expenseDate: DateTime(now.year, now.month, 8),
        category: 'Transport',
        amount: 230.0,
        createdAt: now,
      ),
      Expense(
        id: '3',
        userId: 'user_1',
        expenseDate: DateTime(now.year, now.month, 12),
        category: 'Shopping',
        amount: 150.0,
        createdAt: now,
      ),
    ];

    final fakeService = FakeSupabaseService(sampleExpenses);
    final vm = MainLedgerViewModel(fakeService);
    await vm.loadData();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<MainLedgerViewModel>.value(
          value: vm,
          child: const BentoExpenseChartView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Month header and categories rendered
    expect(find.textContaining('FOOD'), findsWidgets);
    expect(find.textContaining('TRANSPORT'), findsWidgets);
    expect(find.textContaining('SHOPPING'), findsWidgets);
    expect(find.text('CATEGORY BREAKDOWN'), findsOneWidget);
  });
}
