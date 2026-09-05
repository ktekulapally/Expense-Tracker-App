import 'package:intl/intl.dart';

class Expense {
  final String id;
  final String userId;
  final DateTime expenseDate;
  final String category;
  final String? description;
  final double amount;
  final DateTime createdAt;
  final String? recurringId;
  final String? ledgerId;

  Expense({
    required this.id,
    required this.userId,
    required this.expenseDate,
    required this.category,
    this.description,
    required this.amount,
    required this.createdAt,
    this.recurringId,
    this.ledgerId,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      category: json['category'] as String,
      description: json['description'] as String?,
      amount: double.parse(json['amount'].toString()),
      createdAt: DateTime.parse(json['created_at'] as String),
      recurringId: json['recurring_id'] as String?,
      ledgerId: json['ledger_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (userId.isNotEmpty) 'user_id': userId,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'category': category,
      'description': description,
      'amount': amount,
      if (recurringId != null) 'recurring_id': recurringId,
      'ledger_id': ledgerId,
    };
  }
}

class Income {
  final String id;
  final String userId;
  final DateTime incomeDate;
  final String source;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final String? ledgerId;

  Income({
    required this.id,
    required this.userId,
    required this.incomeDate,
    required this.source,
    required this.amount,
    this.notes,
    required this.createdAt,
    this.ledgerId,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      incomeDate: DateTime.parse(json['income_date'] as String),
      source: json['source'] as String,
      amount: double.parse(json['amount'].toString()),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      ledgerId: json['ledger_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (userId.isNotEmpty) 'user_id': userId,
      'income_date': DateFormat('yyyy-MM-dd').format(incomeDate),
      'source': source,
      'amount': amount,
      'notes': notes,
      'ledger_id': ledgerId,
    };
  }
}

class RecurringExpense {
  final String id;
  final String userId;
  final String name;
  final String category;
  final double amount;
  final int paymentDay;
  final bool notifyEmail;
  final bool notifySms;
  final bool active;
  final DateTime createdAt;

  RecurringExpense({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.amount,
    required this.paymentDay,
    required this.notifyEmail,
    required this.notifySms,
    required this.active,
    required this.createdAt,
  });

  factory RecurringExpense.fromJson(Map<String, dynamic> json) {
    return RecurringExpense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      amount: double.parse(json['amount'].toString()),
      paymentDay: json['payment_day'] as int,
      notifyEmail: json['notify_email'] as bool? ?? true,
      notifySms: json['notify_sms'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'amount': amount,
      'payment_day': paymentDay,
      'notify_email': notifyEmail,
      'notify_sms': notifySms,
      'active': active,
    };
  }
}

class NotificationSettings {
  final String userId;
  final String? alertEmail;
  final String? phoneNumber;
  final bool smsEnabled;
  final DateTime updatedAt;

  NotificationSettings({
    required this.userId,
    this.alertEmail,
    this.phoneNumber,
    required this.smsEnabled,
    required this.updatedAt,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      userId: json['user_id'] as String,
      alertEmail: json['alert_email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_email': alertEmail,
      'phone_number': phoneNumber,
      'sms_enabled': smsEnabled,
    };
  }
}

class Ledger {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;

  Ledger({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  factory Ledger.fromJson(Map<String, dynamic> json) {
    return Ledger(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}

class LedgerCategory {
  final String id;
  final String userId;
  final String ledgerId;
  final String name;

  LedgerCategory({
    required this.id,
    required this.userId,
    required this.ledgerId,
    required this.name,
  });

  factory LedgerCategory.fromJson(Map<String, dynamic> json) {
    return LedgerCategory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ledgerId: json['ledger_id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ledger_id': ledgerId,
      'name': name,
    };
  }
}
