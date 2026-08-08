import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Credentials are hardcoded matching the web application configuration
  static const String supabaseUrl = "https://zmklfmlppceiulaybjga.supabase.co";
  static const String supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpta2xmbWxwcGNlaXVsYXliamdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwMDE3MTQsImV4cCI6MjA5ODU3NzcxNH0.XIQPpuEE1QeEcdbubDxd28hfB4dhMbmNy0QIYWkzrGg";

  // Auth Operations
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'personalledger://reset-password',
    );
  }

  // Expenses Operations
  Future<List<Expense>> getExpenses({String? ledgerId}) async {
    var query = _client.from('expenses').select('*');
    if (ledgerId != null) {
      query = query.eq('ledger_id', ledgerId);
    } else {
      query = query.isFilter('ledger_id', null);
    }
    final data = await query.order('expense_date', ascending: false).order('created_at', ascending: false);
    return (data as List).map((json) => Expense.fromJson(json)).toList();
  }

  Future<void> addExpense(Expense expense) async {
    await _client.from('expenses').insert(expense.toJson());
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    await _client.from('expenses').update(data).eq('id', id);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  // Income Operations
  Future<List<Income>> getIncome({String? ledgerId}) async {
    var query = _client.from('income').select('*');
    if (ledgerId != null) {
      query = query.eq('ledger_id', ledgerId);
    } else {
      query = query.isFilter('ledger_id', null);
    }
    final data = await query.order('income_date', ascending: false).order('created_at', ascending: false);
    return (data as List).map((json) => Income.fromJson(json)).toList();
  }

  Future<void> addIncome(Income income) async {
    await _client.from('income').insert(income.toJson());
  }

  Future<void> updateIncome(String id, Map<String, dynamic> data) async {
    await _client.from('income').update(data).eq('id', id);
  }

  Future<void> deleteIncome(String id) async {
    await _client.from('income').delete().eq('id', id);
  }

  // Custom Ledgers
  Future<List<Ledger>> getLedgers() async {
    final data = await _client.from('ledgers').select('*').order('created_at', ascending: true);
    return (data as List).map((json) => Ledger.fromJson(json)).toList();
  }

  Future<void> addLedger(String name, String userId) async {
    await _client.from('ledgers').insert({'user_id': userId, 'name': name});
  }

  Future<void> deleteLedger(String id) async {
    await _client.from('ledgers').delete().eq('id', id);
  }

  // Custom Ledger Categories
  Future<List<LedgerCategory>> getLedgerCategories(String ledgerId) async {
    final data = await _client.from('ledger_categories').select('*').eq('ledger_id', ledgerId).order('name');
    return (data as List).map((json) => LedgerCategory.fromJson(json)).toList();
  }

  Future<void> addLedgerCategory(String ledgerId, String name, String userId) async {
    await _client.from('ledger_categories').insert({
      'user_id': userId,
      'ledger_id': ledgerId,
      'name': name,
    });
  }

  // Recurring Expenses
  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final data = await _client.from('recurring_expenses').select('*').order('payment_day', ascending: true);
    return (data as List).map((json) => RecurringExpense.fromJson(json)).toList();
  }

  Future<void> addRecurringExpense(RecurringExpense template) async {
    await _client.from('recurring_expenses').insert(template.toJson());
  }

  Future<void> updateRecurringExpense(String id, Map<String, dynamic> data) async {
    await _client.from('recurring_expenses').update(data).eq('id', id);
  }

  Future<void> deleteRecurringExpense(String id) async {
    await _client.from('recurring_expenses').delete().eq('id', id);
  }

  // Notification Settings
  Future<NotificationSettings?> getNotificationSettings(String userId) async {
    final data = await _client.from('notification_settings').select('*').eq('user_id', userId).maybeSingle();
    if (data == null) return null;
    return NotificationSettings.fromJson(data);
  }

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    await _client.from('notification_settings').upsert({
      'user_id': settings.userId,
      'alert_email': settings.alertEmail,
      'phone_number': settings.phoneNumber,
      'sms_enabled': settings.smsEnabled,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // AI Analysis (Edge Function invocation)
  Future<Map<String, dynamic>> analyzeSpending({required String period, String? ledgerId}) async {
    final token = currentSession?.accessToken;
    if (token == null) {
      throw Exception('Your session expired — please sign in again.');
    }

    final Map<String, dynamic> body = {'period': period};
    if (ledgerId != null) {
      body['ledgerId'] = ledgerId;
    }

    final response = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/analyze-spending'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final errData = jsonDecode(response.body);
      throw Exception(errData['error'] ?? 'Something went wrong analyzing spending.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
