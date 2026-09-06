import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:personal_ledger_app/data/models.dart';
import 'package:personal_ledger_app/data/services/supabase_service.dart';
import 'package:personal_ledger_app/view_models/main_ledger_view_model.dart';
import 'package:personal_ledger_app/view_models/recurring_view_model.dart';
import 'package:personal_ledger_app/ui/features/insights/ai_advisor_tab.dart';

class FakeSupabaseService extends SupabaseService {
  final List<Expense> expenses;
  final List<Income> income;
  final List<RecurringExpense> recurring;

  FakeSupabaseService(this.expenses, this.income, this.recurring);

  @override
  Future<List<Expense>> getExpenses({String? ledgerId}) async => expenses;

  @override
  Future<List<Income>> getIncome({String? ledgerId}) async => income;

  @override
  Future<List<RecurringExpense>> getRecurringExpenses() async => recurring;

  @override
  Future<NotificationSettings?> getNotificationSettings(String userId) async => null;
}

void main() {
  testWidgets('AiAdvisorTab renders controls and executes financial health audit', (tester) async {
    final now = DateTime.now();
    final sampleExpenses = [
      Expense(
        id: '1',
        userId: 'user_1',
        expenseDate: DateTime(now.year, now.month, 5),
        category: 'Groceries',
        amount: 8000.0,
        createdAt: now,
      ),
      Expense(
        id: '2',
        userId: 'user_1',
        expenseDate: DateTime(now.year, now.month, 10),
        category: 'Food',
        amount: 3000.0,
        createdAt: now,
      ),
      Expense(
        id: '3',
        userId: 'user_1',
        expenseDate: DateTime(now.year, now.month, 15),
        category: 'Electricity Bills',
        amount: 1500.0,
        createdAt: now,
      ),
    ];

    final sampleIncome = [
      Income(
        id: '1',
        userId: 'user_1',
        incomeDate: DateTime(now.year, now.month, 1),
        source: 'Salary',
        amount: 50000.0,
        createdAt: now,
      ),
    ];

    final fakeService = FakeSupabaseService(sampleExpenses, sampleIncome, []);
    final mainVm = MainLedgerViewModel(fakeService);
    final recurringVm = RecurringViewModel(fakeService);

    await mainVm.loadData();
    await recurringVm.loadAll('user_1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<MainLedgerViewModel>.value(value: mainVm),
              ChangeNotifierProvider<RecurringViewModel>.value(value: recurringVm),
            ],
            child: const AiAdvisorTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial screen elements
    expect(find.text('AI Financial Health Advisor'), findsOneWidget);
    expect(find.text('Run Financial Health Audit'), findsOneWidget);
    expect(find.text('Ready for Financial Audit'), findsOneWidget);

    // Tap "Run Financial Health Audit"
    await tester.tap(find.text('Run Financial Health Audit'));
    await tester.pumpAndSettle();

    // Verify advisory output sections
    expect(find.text('FINANCIAL HEALTH STATUS'), findsOneWidget);
    expect(find.text('50 / 30 / 20 Budgeting Rule'), findsOneWidget);
    expect(find.text('Category Spending Breakdown'), findsOneWidget);
    expect(find.text('Key Spending Observations'), findsOneWidget);
    expect(find.text('Recommended Cost-Cutting Levers'), findsOneWidget);
    expect(find.text('Target Budgets for Next Month'), findsOneWidget);
  });
}
