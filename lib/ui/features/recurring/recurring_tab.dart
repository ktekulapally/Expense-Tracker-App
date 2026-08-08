import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../view_models/recurring_view_model.dart';
import '../../../view_models/auth_view_model.dart';
import '../../../data/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class RecurringTab extends StatefulWidget {
  const RecurringTab({super.key});

  @override
  State<RecurringTab> createState() => _RecurringTabState();
}

class _RecurringTabState extends State<RecurringTab> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dayController = TextEditingController();

  final _alertEmailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCategory = 'Utilities';
  bool _notifyEmail = true;
  bool _notifySms = false;
  bool _smsEnabledSetting = false;

  RecurringExpense? _editingTemplate;

  final List<String> _categories = [
    'Utilities',
    'Rent',
    'Groceries',
    'Fuel',
    'Adhoc',
    'Food',
    'Entertainment',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthViewModel>().currentUser?.id ?? '';
      context.read<RecurringViewModel>().loadAll(userId).then((_) {
        final settings = context.read<RecurringViewModel>().settings;
        if (settings != null) {
          _alertEmailController.text = settings.alertEmail ?? '';
          _phoneController.text = settings.phoneNumber ?? '';
          setState(() {
            _smsEnabledSetting = settings.smsEnabled;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    _alertEmailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _enterEditMode(RecurringExpense template) {
    setState(() {
      _editingTemplate = template;
      _nameController.text = template.name;
      _amountController.text = template.amount.toString();
      _dayController.text = template.paymentDay.toString();
      _selectedCategory = _categories.contains(template.category) ? template.category : 'Others';
      _notifyEmail = template.notifyEmail;
      _notifySms = template.notifySms;
    });
  }

  void _exitEditMode() {
    setState(() {
      _editingTemplate = null;
      _nameController.clear();
      _amountController.clear();
      _dayController.clear();
      _notifyEmail = true;
      _notifySms = false;
    });
  }

  Future<void> _saveTemplate(RecurringViewModel vm, String userId) async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text);
    final day = int.tryParse(_dayController.text);

    if (name.isEmpty || amount == null || amount <= 0 || day == null || day < 1 || day > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields correctly (Day must be 1-31).')),
      );
      return;
    }

    try {
      if (_editingTemplate != null) {
        final updated = RecurringExpense(
          id: _editingTemplate!.id,
          userId: userId,
          name: name,
          category: _selectedCategory,
          amount: amount,
          paymentDay: day,
          notifyEmail: _notifyEmail,
          notifySms: _notifySms,
          active: _editingTemplate!.active,
          createdAt: _editingTemplate!.createdAt,
        );
        await vm.updateRecurringExpense(_editingTemplate!.id, updated);
        _exitEditMode();
      } else {
        final newTemplate = RecurringExpense(
          id: '',
          userId: userId,
          name: name,
          category: _selectedCategory,
          amount: amount,
          paymentDay: day,
          notifyEmail: _notifyEmail,
          notifySms: _notifySms,
          active: true,
          createdAt: DateTime.now(),
        );
        await vm.addRecurringExpense(newTemplate);
        _nameController.clear();
        _amountController.clear();
        _dayController.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved template successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save template: $e')),
      );
    }
  }

  Future<void> _saveSettings(RecurringViewModel vm, String userId) async {
    final email = _alertEmailController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      final settings = NotificationSettings(
        userId: userId,
        alertEmail: email.isEmpty ? null : email,
        phoneNumber: phone.isEmpty ? null : phone,
        smsEnabled: _smsEnabledSetting,
        updatedAt: DateTime.now(),
      );
      await vm.saveSettings(settings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.settingsMessage ?? 'Settings saved.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecurringViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final colors = AppTheme.recurringColors;
    final userId = authVm.currentUser?.id ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add/Edit Template Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editingTemplate != null ? "Edit template" : "Add a recurring expense",
                    style: AppTheme.getSubHeadingStyle(colors, size: 16),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: "Name",
                    placeholder: "e.g. Internet Bill, Rent, Gym",
                    controller: _nameController,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: "Amount",
                          placeholder: "0.00",
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: "Due Day (1-31)",
                          placeholder: "e.g. 5",
                          controller: _dayController,
                          keyboardType: TextInputType.number,
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<String>(
                    label: "Category",
                    value: _selectedCategory,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _notifyEmail,
                        activeColor: colors.ink,
                        onChanged: (val) => setState(() => _notifyEmail = val ?? true),
                      ),
                      Text("Email Alert", style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w500)),
                      const SizedBox(width: 24),
                      Checkbox(
                        value: _notifySms,
                        activeColor: colors.ink,
                        onChanged: (val) => setState(() => _notifySms = val ?? false),
                      ),
                      Text("SMS Alert", style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_editingTemplate != null) ...[
                        AppButton(
                          text: "Cancel",
                          isPrimary: false,
                          colors: colors,
                          onPressed: _exitEditMode,
                        ),
                        const SizedBox(width: 12),
                      ],
                      AppButton(
                        text: _editingTemplate != null ? "Update template" : "Save template",
                        isLoading: vm.isLoading,
                        colors: colors,
                        onPressed: () => _saveTemplate(vm, userId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Notification Settings Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Notification Settings",
                    style: AppTheme.getSubHeadingStyle(colors, size: 16),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: "Alert Email",
                    placeholder: authVm.currentUser?.email ?? "your@email.com",
                    controller: _alertEmailController,
                    keyboardType: TextInputType.emailAddress,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: "Phone Number",
                    placeholder: "+91 99999 99999",
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Switch(
                        value: _smsEnabledSetting,
                        activeColor: colors.ink,
                        onChanged: (val) => setState(() => _smsEnabledSetting = val),
                      ),
                      const SizedBox(width: 8),
                      Text("Enable SMS alerts", style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AppButton(
                        text: "Save settings",
                        isLoading: vm.isLoading,
                        colors: colors,
                        onPressed: () => _saveSettings(vm, userId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Your recurring expenses",
              style: AppTheme.getSubHeadingStyle(colors, size: 18),
            ),
          ),
          const SizedBox(height: 8),

          // Lists
          if (vm.recurringExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  "No recurring expenses set up yet.",
                  style: AppTheme.getBodyStyle(colors, soft: true),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: vm.recurringExpenses.length,
              itemBuilder: (context, index) {
                final t = vm.recurringExpenses[index];

                return Card(
                  color: t.active ? Colors.white : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colors.paperLine),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t.name,
                              style: AppTheme.getSubHeadingStyle(colors, size: 15).copyWith(
                                color: t.active ? colors.ink : colors.inkSoft.withOpacity(0.5),
                              ),
                            ),
                            Text(
                              "₹${t.amount.toStringAsFixed(2)}",
                              style: AppTheme.getMonoStyle(colors, size: 14, weight: FontWeight.w600).copyWith(
                                color: t.active ? colors.red : colors.red.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${t.category} · Due on the ${t.paymentDay}${t.paymentDay == 1 ? 'st' : (t.paymentDay == 2 ? 'nd' : (t.paymentDay == 3 ? 'rd' : 'th'))}",
                              style: AppTheme.getBodyStyle(colors, size: 12, soft: true),
                            ),
                            Switch(
                              value: t.active,
                              activeColor: colors.ink,
                              onChanged: (_) => vm.toggleRecurringActive(t.id, t),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppButton(
                              text: "Log this month",
                              isPrimary: false,
                              colors: colors,
                              onPressed: () async {
                                await vm.logRecurringExpense(t);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Logged ${t.name} to expenses.')),
                                );
                              },
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: colors.inkSoft),
                                  onPressed: () => _enterEditMode(t),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18, color: colors.red),
                                  onPressed: () async {
                                    final confirm = await showConfirmDialog(
                                      context: context,
                                      title: "Delete Template?",
                                      content: "Permanently delete the recurring template '${t.name}'?",
                                      colors: colors,
                                    );
                                    if (confirm == true) {
                                      vm.deleteRecurringExpense(t.id, userId);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
