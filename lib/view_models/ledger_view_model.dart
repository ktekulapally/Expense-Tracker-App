import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/services/supabase_service.dart';

class LedgerWithTotals {
  final Ledger ledger;
  final double totalIncome;
  final double totalExpense;

  LedgerWithTotals({
    required this.ledger,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class LedgerViewModel extends ChangeNotifier {
  final SupabaseService _service;

  LedgerViewModel(this._service);

  List<LedgerWithTotals> _ledgers = [];
  List<LedgerWithTotals> get ledgers => _ledgers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadLedgers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rawLedgers = await _service.getLedgers();
      final List<LedgerWithTotals> result = [];

      for (var l in rawLedgers) {
        final expenses = await _service.getExpenses(ledgerId: l.id);
        final income = await _service.getIncome(ledgerId: l.id);

        final totalExp = expenses.fold(0.0, (sum, item) => sum + item.amount);
        final totalInc = income.fold(0.0, (sum, item) => sum + item.amount);

        result.add(LedgerWithTotals(
          ledger: l,
          totalIncome: totalInc,
          totalExpense: totalExp,
        ));
      }

      _ledgers = result;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLedger(String name, String userId) async {
    if (name.trim().isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.addLedger(name.trim(), userId);
      await loadLedgers();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteLedger(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteLedger(id);
      await loadLedgers();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
