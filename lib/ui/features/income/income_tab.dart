import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import '../../../view_models/main_ledger_view_model.dart';
import '../../../view_models/auth_view_model.dart';
import '../../../data/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<IncomeTab> {
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedSource = 'Salary';
  Income? _editingIncome;

  final List<String> _sources = [
    'Salary',
    'Business',
    'Investments',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainLedgerViewModel>().loadData();
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _enterEditMode(Income inc) {
    setState(() {
      _editingIncome = inc;
      _selectedDate = inc.incomeDate;
      _dateController.text = DateFormat('yyyy-MM-dd').format(inc.incomeDate);
      _amountController.text = inc.amount.toString();
      _selectedSource = _sources.contains(inc.source) ? inc.source : 'Others';
      _notesController.text = inc.notes ?? '';
    });
  }

  void _exitEditMode() {
    setState(() {
      _editingIncome = null;
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _amountController.text = '';
      _notesController.text = '';
    });
  }

  Future<void> _saveEntry(MainLedgerViewModel vm, String userId) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    try {
      if (_editingIncome != null) {
        final updated = Income(
          id: _editingIncome!.id,
          userId: userId,
          incomeDate: _selectedDate,
          source: _selectedSource,
          amount: amount,
          notes: _notesController.text.trim(),
          createdAt: _editingIncome!.createdAt,
        );
        await vm.updateIncome(_editingIncome!.id, updated);
        _exitEditMode();
      } else {
        final newInc = Income(
          id: '',
          userId: userId,
          incomeDate: _selectedDate,
          source: _selectedSource,
          amount: amount,
          notes: _notesController.text.trim(),
          createdAt: DateTime.now(),
        );
        await vm.addIncome(newInc);
        _amountController.text = '';
        _notesController.text = '';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved entry successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  // Export to CSV and share
  Future<void> _exportExcel(List<Income> list) async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Source,Notes,Amount');
    for (var i in list) {
      final date = DateFormat('yyyy-MM-dd').format(i.incomeDate);
      final notes = i.notes?.replaceAll('"', '""') ?? '';
      buffer.writeln('$date,${i.source},"$notes",${i.amount}');
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/income_export.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Income CSV Export');
  }

  // Export to PDF and open/share
  Future<void> _exportPdf(List<Income> list, AppThemeColors colors) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Personal Ledger — Income Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Source', 'Notes', 'Amount (INR)'],
                data: list.map((i) => [
                  DateFormat('yyyy-MM-dd').format(i.incomeDate),
                  i.source,
                  i.notes ?? '',
                  'Rs. ${i.amount.toStringAsFixed(2)}'
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Total: Rs. ${list.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/income_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainLedgerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final colors = AppTheme.incomeColors;

    final userId = authVm.currentUser?.id ?? '';
    final incomeList = vm.filteredIncome;

    return Column(
      children: [
        // Statistics Header
        Padding(
          padding: const EdgeInsets.all(16),
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

        // Add/Edit Income Form Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(colors),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _editingIncome != null ? 'Edit income entry' : 'Add income',
                  style: AppTheme.getSubHeadingStyle(colors, size: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Date",
                        controller: _dateController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: "Amount",
                        placeholder: "0.00",
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        label: "Source",
                        value: _selectedSource,
                        items: _sources.map((s) {
                          return DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSource = val);
                          }
                        },
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: "Notes",
                        placeholder: "Optional notes",
                        controller: _notesController,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_editingIncome != null) ...[
                      AppButton(
                        text: "Cancel",
                        isPrimary: false,
                        colors: colors,
                        onPressed: _exitEditMode,
                      ),
                      const SizedBox(width: 12),
                    ],
                    AppButton(
                      text: _editingIncome != null ? "Update entry" : "Add entry",
                      isLoading: vm.isLoading,
                      colors: colors,
                      onPressed: () => _saveEntry(vm, userId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Filters card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration(colors),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        label: "Month Filter",
                        value: vm.incomeMonthFilter,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All months')),
                          ...vm.incomeMonths.map((m) {
                            final date = DateTime.parse('$m-01');
                            final label = DateFormat('MMMM yyyy').format(date);
                            return DropdownMenuItem(value: m, child: Text(label));
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) vm.setIncomeMonthFilter(val);
                        },
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<String>(
                        label: "Source Filter",
                        value: vm.incomeSourceFilter,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All sources')),
                          ...vm.incomeSources.map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) vm.setIncomeSourceFilter(val);
                        },
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (val) => vm.setIncomeSearch(val),
                  decoration: InputDecoration(
                    hintText: "Search notes or sources...",
                    hintStyle: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: colors.inkSoft),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colors.paperLine),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colors.ink),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Export toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                text: "Export CSV",
                isGhost: true,
                colors: colors,
                onPressed: () => _exportExcel(incomeList),
              ),
              const SizedBox(width: 8),
              AppButton(
                text: "Export PDF",
                isGhost: true,
                colors: colors,
                onPressed: () => _exportPdf(incomeList, colors),
              ),
            ],
          ),
        ),

        // List of entries
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: incomeList.length,
            itemBuilder: (context, index) {
              final i = incomeList[index];
              final dateStr = DateFormat('yyyy-MM-dd').format(i.incomeDate);

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.paperLine),
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i.source,
                        style: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 14),
                      ),
                      Text(
                        "₹${i.amount.toStringAsFixed(2)}",
                        style: AppTheme.getMonoStyle(colors, size: 14, weight: FontWeight.w600).copyWith(
                          color: colors.green,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i.notes != null && i.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          i.notes!,
                          style: AppTheme.getBodyStyle(colors, size: 13, soft: true),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: AppTheme.getMonoStyle(colors, size: 11).copyWith(color: colors.inkSoft),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18, color: colors.inkSoft),
                        onPressed: () => _enterEditMode(i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 18, color: colors.red),
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
        ),
      ],
    );
  }
}
