import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/services/supabase_service.dart';

class MainLedgerViewModel extends ChangeNotifier {
  final SupabaseService _service;

  MainLedgerViewModel(this._service);

  List<Expense> _allExpenses = [];
  List<Expense> get allExpenses => _allExpenses;

  List<Income> _allIncome = [];
  List<Income> get allIncome => _allIncome;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Filters
  String _expenseMonthFilter = 'all';
  String get expenseMonthFilter => _expenseMonthFilter;

  String _expenseCategoryFilter = 'all';
  String get expenseCategoryFilter => _expenseCategoryFilter;

  String _expenseSearchQuery = '';
  String get expenseSearchQuery => _expenseSearchQuery;

  // Income Filters
  String _incomeMonthFilter = 'all';
  String get incomeMonthFilter => _incomeMonthFilter;

  String _incomeSourceFilter = 'all';
  String get incomeSourceFilter => _incomeSourceFilter;

  String _incomeSearchQuery = '';
  String get incomeSearchQuery => _incomeSearchQuery;

  // Stats (Calculated on current month data)
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

  void setIncomeMonthFilter(String month) {
    _incomeMonthFilter = month;
    notifyListeners();
  }

  void setIncomeSourceFilter(String source) {
    _incomeSourceFilter = source;
    notifyListeners();
  }

  void setIncomeSearch(String search) {
    _incomeSearchQuery = search.toLowerCase();
    notifyListeners();
  }

  // Load Data
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getExpenses(),
        _service.getIncome(),
      ]);

      _allExpenses = results[0] as List<Expense>;
      _allIncome = results[1] as List<Income>;

      _calculateStats();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filtered lists
  List<Expense> get filteredExpenses {
    return _allExpenses.where((e) {
      // Month Filter
      if (_expenseMonthFilter != 'all') {
        final monthStr = e.expenseDate.toIso8601String().substring(0, 7);
        if (monthStr != _expenseMonthFilter) return false;
      }
      // Category Filter
      if (_expenseCategoryFilter != 'all' && e.category != _expenseCategoryFilter) {
        return false;
      }
      // Search Query
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

  List<Income> get filteredIncome {
    return _allIncome.where((inc) {
      // Month Filter
      if (_incomeMonthFilter != 'all') {
        final monthStr = inc.incomeDate.toIso8601String().substring(0, 7);
        if (monthStr != _incomeMonthFilter) return false;
      }
      // Source Filter
      if (_incomeSourceFilter != 'all' && inc.source != _incomeSourceFilter) {
        return false;
      }
      // Search Query
      if (_incomeSearchQuery.isNotEmpty) {
        final note = inc.notes?.toLowerCase() ?? '';
        final src = inc.source.toLowerCase();
        if (!note.contains(_incomeSearchQuery) && !src.contains(_incomeSearchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Helper to extract unique months
  List<String> get expenseMonths {
    final months = _allExpenses.map((e) => e.expenseDate.toIso8601String().substring(0, 7)).toSet().toList();
    months.sort((a, b) => b.compareTo(a)); // desc
    return months;
  }

  List<String> get expenseCategories {
    final categories = _allExpenses.map((e) => e.category).toSet().toList();
    categories.sort();
    return categories;
  }

  List<String> get incomeMonths {
    final months = _allIncome.map((i) => i.incomeDate.toIso8601String().substring(0, 7)).toSet().toList();
    months.sort((a, b) => b.compareTo(a)); // desc
    return months;
  }

  List<String> get incomeSources {
    final sources = _allIncome.map((i) => i.source).toSet().toList();
    sources.sort();
    return sources;
  }

  // Calculate current month statistics (matches web client logic)
  void _calculateStats() {
    final now = DateTime.now();
    final currentMonthPrefix = now.toIso8601String().substring(0, 7); // e.g. "2026-08"

    _monthExpensesTotal = _allExpenses
        .where((e) => e.expenseDate.toIso8601String().startsWith(currentMonthPrefix))
        .fold(0.0, (sum, item) => sum + item.amount);

    _monthIncomeTotal = _allIncome
        .where((i) => i.incomeDate.toIso8601String().startsWith(currentMonthPrefix))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  // CRUD Operations
  Future<void> addExpense(Expense expense) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.addExpense(expense);
      await loadData();
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
      await loadData();
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
      await loadData();
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
      await loadData();
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
      await loadData();
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
      await loadData();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
