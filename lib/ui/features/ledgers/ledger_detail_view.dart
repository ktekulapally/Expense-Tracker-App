import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/models.dart';
import '../../../data/services/supabase_service.dart';
import '../../../view_models/custom_ledger_detail_view_model.dart';
import '../../../view_models/auth_view_model.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/background_painter.dart';

class LedgerDetailView extends StatefulWidget {
  final Ledger ledger;

  const LedgerDetailView({super.key, required this.ledger});

  @override
  State<LedgerDetailView> createState() => _LedgerDetailViewState();
}

class _LedgerDetailViewState extends State<LedgerDetailView> with SingleTickerProviderStateMixin {
  late CustomLedgerDetailViewModel _viewModel;
  late TabController _tabController;

  // Expense controllers
  final _expDateController = TextEditingController();
  final _expAmountController = TextEditingController();
  final _expDescController = TextEditingController();
  String? _selectedCategory;
  Expense? _editingExpense;

  // Income controllers
  final _incDateController = TextEditingController();
  final _incAmountController = TextEditingController();
  final _incNotesController = TextEditingController();
  String _selectedSource = 'Business';
  Income? _editingIncome;

  // Category addition
  final _newCategoryController = TextEditingController();
  bool _showNewCategoryField = false;

  DateTime _selectedExpDate = DateTime.now();
  DateTime _selectedIncDate = DateTime.now();

  final List<String> _incomeSources = ['Salary', 'Business', 'Investments', 'Others'];
  String _aiPeriod = '3m';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _viewModel = CustomLedgerDetailViewModel(
      context.read<SupabaseService>(),
      widget.ledger.id,
    );

    _expDateController.text = DateFormat('yyyy-MM-dd').format(_selectedExpDate);
    _incDateController.text = DateFormat('yyyy-MM-dd').format(_selectedIncDate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadAll().then((_) {
        if (_viewModel.categories.isNotEmpty) {
          setState(() {
            _selectedCategory = _viewModel.categories.first.name;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expDateController.dispose();
    _expAmountController.dispose();
    _expDescController.dispose();
    _incDateController.dispose();
    _incAmountController.dispose();
    _incNotesController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  // Pickers
  void _selectExpDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedExpDate = picked;
        _expDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _selectIncDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedIncDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedIncDate = picked;
        _incDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // Add category
  Future<void> _addNewCategory(String userId) async {
    final newCat = _newCategoryController.text.trim();
    if (newCat.isEmpty) return;

    try {
      await _viewModel.addCategory(newCat, userId);
      setState(() {
        _selectedCategory = newCat;
        _showNewCategoryField = false;
        _newCategoryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add category: $e')),
      );
    }
  }

  // CRUD actions
  Future<void> _saveExpense(String userId) async {
    final amount = double.tryParse(_expAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a category.')));
      return;
    }

    try {
      if (_editingExpense != null) {
        final updated = Expense(
          id: _editingExpense!.id,
          userId: userId,
          expenseDate: _selectedExpDate,
          category: _selectedCategory!,
          description: _expDescController.text.trim(),
          amount: amount,
          createdAt: _editingExpense!.createdAt,
          ledgerId: widget.ledger.id,
        );
        await _viewModel.updateExpense(_editingExpense!.id, updated);
        _exitExpenseEdit();
      } else {
        final newExp = Expense(
          id: '',
          userId: userId,
          expenseDate: _selectedExpDate,
          category: _selectedCategory!,
          description: _expDescController.text.trim(),
          amount: amount,
          createdAt: DateTime.now(),
          ledgerId: widget.ledger.id,
        );
        await _viewModel.addExpense(newExp);
        _expAmountController.clear();
        _expDescController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  void _enterExpenseEdit(Expense e) {
    setState(() {
      _editingExpense = e;
      _selectedExpDate = e.expenseDate;
      _expDateController.text = DateFormat('yyyy-MM-dd').format(e.expenseDate);
      _expAmountController.text = e.amount.toString();
      _selectedCategory = e.category;
      _expDescController.text = e.description ?? '';
    });
  }

  void _exitExpenseEdit() {
    setState(() {
      _editingExpense = null;
      _selectedExpDate = DateTime.now();
      _expDateController.text = DateFormat('yyyy-MM-dd').format(_selectedExpDate);
      _expAmountController.clear();
      _expDescController.clear();
    });
  }

  Future<void> _saveIncome(String userId) async {
    final amount = double.tryParse(_incAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    try {
      if (_editingIncome != null) {
        final updated = Income(
          id: _editingIncome!.id,
          userId: userId,
          incomeDate: _selectedIncDate,
          source: _selectedSource,
          amount: amount,
          notes: _incNotesController.text.trim(),
          createdAt: _editingIncome!.createdAt,
          ledgerId: widget.ledger.id,
        );
        await _viewModel.updateIncome(_editingIncome!.id, updated);
        _exitIncomeEdit();
      } else {
        final newInc = Income(
          id: '',
          userId: userId,
          incomeDate: _selectedIncDate,
          source: _selectedSource,
          amount: amount,
          notes: _incNotesController.text.trim(),
          createdAt: DateTime.now(),
          ledgerId: widget.ledger.id,
        );
        await _viewModel.addIncome(newInc);
        _incAmountController.clear();
        _incNotesController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  void _enterIncomeEdit(Income i) {
    setState(() {
      _editingIncome = i;
      _selectedIncDate = i.incomeDate;
      _incDateController.text = DateFormat('yyyy-MM-dd').format(i.incomeDate);
      _incAmountController.text = i.amount.toString();
      _selectedSource = _incomeSources.contains(i.source) ? i.source : 'Others';
      _incNotesController.text = i.notes ?? '';
    });
  }

  void _exitIncomeEdit() {
    setState(() {
      _editingIncome = null;
      _selectedIncDate = DateTime.now();
      _incDateController.text = DateFormat('yyyy-MM-dd').format(_selectedIncDate);
      _incAmountController.clear();
      _incNotesController.clear();
    });
  }

  // Share CSV
  Future<void> _exportCSV() async {
    final buffer = StringBuffer();
    buffer.writeln('Type,Date,Category/Source,Description/Notes,Amount');
    for (var e in _viewModel.expenses) {
      buffer.writeln('Expense,${DateFormat('yyyy-MM-dd').format(e.expenseDate)},${e.category},"${e.description ?? ''}",${e.amount}');
    }
    for (var i in _viewModel.income) {
      buffer.writeln('Income,${DateFormat('yyyy-MM-dd').format(i.incomeDate)},${i.source},"${i.notes ?? ''}",${i.amount}');
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${widget.ledger.name}_ledger_export.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: '${widget.ledger.name} CSV Export');
  }

  // Open PDF report
  Future<void> _exportPDF(AppThemeColors colors) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Ledger: ${widget.ledger.name}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Date Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 16),
              pw.Text('Expenses', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Category', 'Description', 'Amount'],
                data: _viewModel.expenses.map((e) => [
                  DateFormat('yyyy-MM-dd').format(e.expenseDate),
                  e.category,
                  e.description ?? '',
                  e.amount.toStringAsFixed(2)
                ]).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Income', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Source', 'Notes', 'Amount'],
                data: _viewModel.income.map((i) => [
                  DateFormat('yyyy-MM-dd').format(i.incomeDate),
                  i.source,
                  i.notes ?? '',
                  i.amount.toStringAsFixed(2)
                ]).toList(),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${widget.ledger.name}_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.ledgersColors;
    final authVm = context.watch<AuthViewModel>();
    final userId = authVm.currentUser?.id ?? '';

    return ChangeNotifierProvider<CustomLedgerDetailViewModel>.value(
      value: _viewModel,
      child: Consumer<CustomLedgerDetailViewModel>(
        builder: (context, vm, _) {
          final expList = vm.filteredExpenses;

          return Scaffold(
            appBar: AppBar(
              backgroundColor: colors.card,
              elevation: 0,
              iconTheme: IconThemeData(color: colors.ink),
              title: Text(
                widget.ledger.name,
                style: AppTheme.getSubHeadingStyle(colors, size: 20),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _exportCSV,
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _exportPDF(colors),
                ),
              ],
            ),
            body: ThemeBackground(
              tab: AppTab.ledgers,
              child: SafeArea(
                child: Column(
                  children: [
                    // Stats top block
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          StatCard(
                            label: "Expenses — This Month",
                            value: "₹${vm.monthExpensesTotal.toStringAsFixed(2)}",
                            isPositive: false,
                            colors: colors,
                          ),
                          const SizedBox(width: 8),
                          StatCard(
                            label: "Income — This Month",
                            value: "₹${vm.monthIncomeTotal.toStringAsFixed(2)}",
                            isPositive: true,
                            colors: colors,
                          ),
                          const SizedBox(width: 8),
                          StatCard(
                            label: "Net — This Month",
                            value: "₹${vm.monthNetTotal.toStringAsFixed(2)}",
                            isPositive: vm.monthNetTotal >= 0,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),

                    // Tab navigation
                    TabBar(
                      controller: _tabController,
                      labelColor: colors.ink,
                      unselectedLabelColor: colors.inkSoft,
                      indicatorColor: colors.brass,
                      labelStyle: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 14),
                      tabs: const [
                        Tab(text: "Expenses"),
                        Tab(text: "Income"),
                        Tab(text: "AI Advisor"),
                      ],
                    ),

                    // Tab View content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 1. Expenses tab
                          _buildExpensesView(vm, userId, expList, colors),

                          // 2. Income tab
                          _buildIncomeView(vm, userId, colors),

                          // 3. AI Advisor tab
                          _buildAiAdvisorView(vm, colors),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpensesView(
      CustomLedgerDetailViewModel vm, String userId, List<Expense> expList, AppThemeColors colors) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add expense card
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editingExpense != null ? "Edit expense" : "Add an expense",
                    style: AppTheme.getSubHeadingStyle(colors, size: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: "Date",
                          controller: _expDateController,
                          readOnly: true,
                          onTap: () => _selectExpDate(context),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: "Amount",
                          placeholder: "0.00",
                          controller: _expAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Category",
                              style: AppTheme.getBodyStyle(colors, soft: true, size: 11, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: colors.paperLine),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  isExpanded: true,
                                  style: AppTheme.getBodyStyle(colors, size: 14),
                                  items: [
                                    if (vm.categories.isEmpty)
                                      const DropdownMenuItem(value: null, child: Text('No categories yet')),
                                    ...vm.categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                                    const DropdownMenuItem(value: '__add_new__', child: Text('+ Add new category…')),
                                  ],
                                  onChanged: (val) {
                                    if (val == '__add_new__') {
                                      setState(() => _showNewCategoryField = true);
                                    } else {
                                      setState(() {
                                        _selectedCategory = val;
                                        _showNewCategoryField = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: "Note",
                          placeholder: "Optional note",
                          controller: _expDescController,
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
  
                  // Inline New Category Input
                  if (_showNewCategoryField) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: "New Category Name",
                            placeholder: "e.g. Fertilizer",
                            controller: _newCategoryController,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          text: "Add",
                          colors: colors,
                          onPressed: () => _addNewCategory(userId),
                        ),
                      ],
                    ),
                  ],
  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_editingExpense != null) ...[
                        AppButton(
                          text: "Cancel",
                          isPrimary: false,
                          colors: colors,
                          onPressed: _exitExpenseEdit,
                        ),
                        const SizedBox(width: 10),
                      ],
                      AppButton(
                        text: _editingExpense != null ? "Update" : "Add Entry",
                        isLoading: vm.isLoading,
                        colors: colors,
                        onPressed: () => _saveExpense(userId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
  
          // Filters card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: AppTheme.cardDecoration(colors),
              child: Row(
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: "Month Filter",
                      value: vm.expenseMonthFilter,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All months')),
                        ...vm.expenseMonths.map((m) {
                          final date = DateTime.parse('$m-01');
                          final label = DateFormat('MMM yy').format(date);
                          return DropdownMenuItem(value: m, child: Text(label));
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) vm.setExpenseMonthFilter(val);
                      },
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppDropdownField<String>(
                      label: "Category Filter",
                      value: vm.expenseCategoryFilter,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All categories')),
                        ...vm.categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                      ],
                      onChanged: (val) {
                        if (val != null) vm.setExpenseCategoryFilter(val);
                      },
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ),
          ),
  
          const SizedBox(height: 10),
  
          // List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: expList.length,
            itemBuilder: (context, index) {
              final e = expList[index];
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.paperLine),
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.category,
                          style: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("₹${e.amount.toStringAsFixed(2)}",
                          style: AppTheme.getMonoStyle(colors, size: 13, weight: FontWeight.w600).copyWith(color: colors.red)),
                    ],
                  ),
                  subtitle: Text(
                    "${e.description ?? ''} · ${DateFormat('yyyy-MM-dd').format(e.expenseDate)}",
                    style: AppTheme.getBodyStyle(colors, size: 12, soft: true),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 16, color: colors.inkSoft),
                        onPressed: () => _enterExpenseEdit(e),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 16, color: colors.red),
                        onPressed: () async {
                          final confirm = await showConfirmDialog(
                            context: context,
                            title: "Delete Entry?",
                            content: "Permanently delete this expense?",
                            colors: colors,
                          );
                          if (confirm == true) {
                            vm.deleteExpense(e.id);
                          }
                        },
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

  Widget _buildIncomeView(CustomLedgerDetailViewModel vm, String userId, AppThemeColors colors) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add income card
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editingIncome != null ? "Edit income entry" : "Add income",
                    style: AppTheme.getSubHeadingStyle(colors, size: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: "Date",
                          controller: _incDateController,
                          readOnly: true,
                          onTap: () => _selectIncDate(context),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: "Amount",
                          placeholder: "0.00",
                          controller: _incAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdownField<String>(
                          label: "Source",
                          value: _selectedSource,
                          items: _incomeSources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSource = val);
                          },
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: "Notes",
                          placeholder: "Optional notes",
                          controller: _incNotesController,
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_editingIncome != null) ...[
                        AppButton(
                          text: "Cancel",
                          isPrimary: false,
                          colors: colors,
                          onPressed: _exitIncomeEdit,
                        ),
                        const SizedBox(width: 10),
                      ],
                      AppButton(
                        text: _editingIncome != null ? "Update" : "Add Entry",
                        isLoading: vm.isLoading,
                        colors: colors,
                        onPressed: () => _saveIncome(userId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
  
          const SizedBox(height: 10),
  
          // List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: vm.income.length,
            itemBuilder: (context, index) {
              final i = vm.income[index];
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.paperLine),
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          i.source,
                          style: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("₹${i.amount.toStringAsFixed(2)}",
                          style: AppTheme.getMonoStyle(colors, size: 13, weight: FontWeight.w600).copyWith(color: colors.green)),
                    ],
                  ),
                  subtitle: Text(
                    "${i.notes ?? ''} · ${DateFormat('yyyy-MM-dd').format(i.incomeDate)}",
                    style: AppTheme.getBodyStyle(colors, size: 12, soft: true),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 16, color: colors.inkSoft),
                        onPressed: () => _enterIncomeEdit(i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 16, color: colors.red),
                        onPressed: () async {
                          final confirm = await showConfirmDialog(
                            context: context,
                            title: "Delete Entry?",
                            content: "Permanently delete this income?",
                            colors: colors,
                          );
                          if (confirm == true) {
                            vm.deleteIncome(i.id);
                          }
                        },
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

  Widget _buildAiAdvisorView(CustomLedgerDetailViewModel vm, AppThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(colors),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Where is this ledger's money going?",
                  style: AppTheme.getSubHeadingStyle(colors, size: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sends a summary of this ledger's category totals to an open-weight LLM for a plain-language read and practical suggestions.",
                  style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                ),
                const SizedBox(height: 16),

                // Range toggles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['1m', '3m', '6m'].map((p) {
                    final isSel = _aiPeriod == p;
                    return OutlinedButton(
                      onPressed: () => setState(() => _aiPeriod = p),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSel ? colors.ink : Colors.white,
                        foregroundColor: isSel ? Colors.white : colors.ink,
                        side: BorderSide(color: colors.paperLine),
                      ),
                      child: Text(p == '1m' ? "Last month" : (p == '3m' ? "Last 3 months" : "Last 6 months")),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                AppButton(
                  text: "Analyze this ledger",
                  isLoading: vm.isAiLoading,
                  colors: colors,
                  onPressed: () => vm.analyzeLedger(_aiPeriod),
                ),

                if (vm.aiError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    vm.aiError!,
                    style: AppTheme.getBodyStyle(colors, size: 13).copyWith(color: colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Output box
          if (vm.isAiLoading)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                children: [
                  CircularProgressIndicator(color: colors.ink),
                  const SizedBox(height: 12),
                  Text("Thinking this through…", style: AppTheme.getBodyStyle(colors, soft: true)),
                ],
              ),
            )
          else if (vm.aiAdvice != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(colors),
              child: MarkdownBody(
                data: vm.aiAdvice!,
                styleSheet: MarkdownStyleSheet(
                  p: AppTheme.getBodyStyle(colors, size: 14),
                  h1: AppTheme.getSubHeadingStyle(colors, size: 20),
                  h2: AppTheme.getSubHeadingStyle(colors, size: 17),
                  listBullet: AppTheme.getBodyStyle(colors, size: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This is general, automatically generated information based on your own logged data — not financial advice.",
              style: AppTheme.getBodyStyle(colors, soft: true, size: 11),
              textAlign: TextAlign.center,
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration(colors),
              child: Center(
                child: Text(
                  "Pick a time range and click \"Analyze this ledger\" to get started.",
                  style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
