import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/services/supabase_service.dart';

class CustomLedgerDetailViewModel extends ChangeNotifier {
  final SupabaseService _service;
  final String ledgerId;

  CustomLedgerDetailViewModel(this._service, this.ledgerId);

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  List<Income> _income = [];
  List<Income> get income => _income;

  List<LedgerCategory> _categories = [];
  List<LedgerCategory> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // AI Advisor variables
  bool _isAiLoading = false;
  bool get isAiLoading => _isAiLoading;

  String? _aiAdvice;
  String? get aiAdvice => _aiAdvice;

  String? _aiError;
  String? get aiError => _aiError;

  // Filters
  String _expenseMonthFilter = 'all';
  String get expenseMonthFilter => _expenseMonthFilter;

  String _expenseCategoryFilter = 'all';
  String get expenseCategoryFilter => _expenseCategoryFilter;

  String _expenseSearchQuery = '';
  String get expenseSearchQuery => _expenseSearchQuery;

  // Stats
  double _monthExpensesTotal = 0.0;
  double get monthExpensesTotal => _monthExpensesTotal;

  double _monthIncomeTotal = 0.0;
  double get monthIncomeTotal => _monthIncomeTotal;

  double get monthNetTotal => _monthIncomeTotal - _monthExpensesTotal;

  // Setters for filters
  void setExpenseMonthFilter(String month) {
    _expenseMonthFilter = month;
    notifyListeners();
  }

  void setExpenseCategoryFilter(String category) {
    _expenseCategoryFilter = category;
    notifyListeners();
  }

  void setExpenseSearch(String search) {
    _expenseSearchQuery = search.toLowerCase();
    notifyListeners();
  }

  // Load All Ledger Details
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getExpenses(ledgerId: ledgerId),
        _service.getIncome(ledgerId: ledgerId),
        _service.getLedgerCategories(ledgerId),
      ]);

      _expenses = results[0] as List<Expense>;
      _income = results[1] as List<Income>;
      _categories = results[2] as List<LedgerCategory>;

      _calculateStats();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Expense> get filteredExpenses {
    return _expenses.where((e) {
      if (_expenseMonthFilter != 'all') {
        final monthStr = e.expenseDate.toIso8601String().substring(0, 7);
        if (monthStr != _expenseMonthFilter) return false;
      }
      if (_expenseCategoryFilter != 'all' && e.category != _expenseCategoryFilter) {
        return false;
      }
      if (_expenseSearchQuery.isNotEmpty) {
        final note = e.description?.toLowerCase() ?? '';
        final cat = e.category.toLowerCase();
        if (!note.contains(_expenseSearchQuery) && !cat.contains(_expenseSearchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get expenseMonths {
    final months = _expenses.map((e) => e.expenseDate.toIso8601String().substring(0, 7)).toSet().toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  // Calculate statistics
  void _calculateStats() {
    final now = DateTime.now();
    final currentMonthPrefix = now.toIso8601String().substring(0, 7);

    _monthExpensesTotal = _expenses
        .where((e) => e.expenseDate.toIso8601String().startsWith(currentMonthPrefix))
        .fold(0.0, (sum, item) => sum + item.amount);

    _monthIncomeTotal = _income
        .where((i) => i.incomeDate.toIso8601String().startsWith(currentMonthPrefix))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  // Categories addition
  Future<void> addCategory(String name, String userId) async {
    if (name.trim().isEmpty) return;
    try {
      await _service.addLedgerCategory(ledgerId, name.trim(), userId);
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // CRUD Operations
  Future<void> addExpense(Expense expense) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.addExpense(expense);
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(String id, Expense updated) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.updateExpense(id, {
        'expense_date': updated.toJson()['expense_date'],
        'category': updated.category,
        'description': updated.description,
        'amount': updated.amount,
      });
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.deleteExpense(id);
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addIncome(Income income) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.addIncome(income);
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateIncome(String id, Income updated) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.updateIncome(id, {
        'income_date': updated.toJson()['income_date'],
        'source': updated.source,
        'amount': updated.amount,
        'notes': updated.notes,
      });
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteIncome(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.deleteIncome(id);
      await loadAll();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Analyze spending specific to this custom ledger
  Future<void> analyzeLedger(String period) async {
    _isAiLoading = true;
    _aiAdvice = null;
    _aiError = null;
    notifyListeners();

    try {
      final res = await _service.analyzeSpending(period: period, ledgerId: ledgerId);
      _aiAdvice = res['advice'] as String?;
    } catch (e) {
      _aiError = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isAiLoading = false;
      notifyListeners();
    }
  }
}
