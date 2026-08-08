import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/services/supabase_service.dart';

class RecurringViewModel extends ChangeNotifier {
  final SupabaseService _service;

  RecurringViewModel(this._service);

  List<RecurringExpense> _recurringExpenses = [];
  List<RecurringExpense> get recurringExpenses => _recurringExpenses;

  NotificationSettings? _settings;
  NotificationSettings? get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _settingsMessage;
  String? get settingsMessage => _settingsMessage;

  // Load Templates & Settings
  Future<void> loadAll(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    _settingsMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getRecurringExpenses(),
        _service.getNotificationSettings(userId),
      ]);

      _recurringExpenses = results[0] as List<RecurringExpense>;
      _settings = results[1] as NotificationSettings?;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // CRUD Recurring
  Future<void> addRecurringExpense(RecurringExpense template) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.addRecurringExpense(template);
      if (template.userId.isNotEmpty) {
        await loadAll(template.userId);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateRecurringExpense(String id, RecurringExpense updated) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.updateRecurringExpense(id, {
        'name': updated.name,
        'category': updated.category,
        'amount': updated.amount,
        'payment_day': updated.paymentDay,
        'notify_email': updated.notifyEmail,
        'notify_sms': updated.notifySms,
        'active': updated.active,
      });
      await loadAll(updated.userId);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleRecurringActive(String id, RecurringExpense current) async {
    try {
      await _service.updateRecurringExpense(id, {'active': !current.active});
      await loadAll(current.userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteRecurringExpense(String id, String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.deleteRecurringExpense(id);
      await loadAll(userId);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Log recurring expense into real expenses
  Future<void> logRecurringExpense(RecurringExpense template) async {
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final newExpense = Expense(
        id: '',
        userId: template.userId,
        expenseDate: now,
        category: template.category,
        description: '${template.name} (Recurring log)',
        amount: template.amount,
        createdAt: now,
        recurringId: template.id,
      );
      await _service.addExpense(newExpense);
      await loadAll(template.userId);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Save Settings
  Future<void> saveSettings(NotificationSettings newSettings) async {
    _isLoading = true;
    _settingsMessage = null;
    notifyListeners();
    try {
      await _service.saveNotificationSettings(newSettings);
      _settings = newSettings;
      _settingsMessage = "Notification settings updated successfully.";
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
