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
import '../../../data/services/ocr_service.dart';
import '../../../data/services/receipt_parser.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Groceries';
  Expense? _editingExpense;

  final OCRService _ocrService = OCRService();
  bool _isOcrLoading = false;

  final List<String> _categories = MainLedgerViewModel.defaultExpenseCategories;

  void _showScanOptions(BuildContext context) {
    final colors = AppTheme.expensesColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: colors.ink),
                title: Text('Take Photo', style: AppTheme.getBodyStyle(colors, weight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _scanReceipt(true);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: colors.ink),
                title: Text('Choose from Gallery', style: AppTheme.getBodyStyle(colors, weight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _scanReceipt(false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanReceipt(bool fromCamera) async {
    setState(() {
      _isOcrLoading = true;
    });

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing receipt OCR...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final parsed = await _ocrService.pickAndParseReceipt(fromCamera);
      // Close the loading dialog
      if (mounted) Navigator.pop(context);

      if (parsed != null) {
        setState(() {
          if (parsed.totalAmount != null) {
            _amountController.text = parsed.totalAmount!.toStringAsFixed(2);
          }
          if (parsed.vendor != null) {
            _descController.text = parsed.vendor!;
          }
          if (parsed.date != null) {
            try {
              final parsedDate = DateTime.parse(parsed.date!);
              _selectedDate = parsedDate;
              _dateController.text = DateFormat('yyyy-MM-dd').format(parsedDate);
            } catch (_) {}
          }
          final suggestion = CategoryMatcher.suggestCategory(parsed.vendor, parsed.lineItems, parsed.rawOcrText);
          if (_categories.contains(suggestion.category)) {
            _selectedCategory = suggestion.category;
          } else {
            _selectedCategory = 'Others';
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Receipt parsed: ${parsed.vendor ?? "Unknown Vendor"}, ₹${parsed.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close dialog if still showing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse receipt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOcrLoading = false;
        });
      }
    }
  }

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
    _descController.dispose();
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

  void _enterEditMode(Expense e) {
    setState(() {
      _editingExpense = e;
      _selectedDate = e.expenseDate;
      _dateController.text = DateFormat('yyyy-MM-dd').format(e.expenseDate);
      _amountController.text = e.amount.toString();
      _selectedCategory = _categories.contains(e.category) ? e.category : 'Others';
      _descController.text = e.description ?? '';
    });
  }

  void _exitEditMode() {
    setState(() {
      _editingExpense = null;
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _amountController.text = '';
      _descController.text = '';
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
      if (_editingExpense != null) {
        final updated = Expense(
          id: _editingExpense!.id,
          userId: userId,
          expenseDate: _selectedDate,
          category: _selectedCategory,
          description: _descController.text.trim(),
          amount: amount,
          createdAt: _editingExpense!.createdAt,
        );
        await vm.updateExpense(_editingExpense!.id, updated);
        _exitEditMode();
      } else {
        final newExp = Expense(
          id: '',
          userId: userId,
          expenseDate: _selectedDate,
          category: _selectedCategory,
          description: _descController.text.trim(),
          amount: amount,
          createdAt: DateTime.now(),
        );
        await vm.addExpense(newExp);
        _amountController.text = '';
        _descController.text = '';
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
  Future<void> _exportExcel(List<Expense> list) async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Category,Description,Amount');
    for (var e in list) {
      final date = DateFormat('yyyy-MM-dd').format(e.expenseDate);
      final desc = e.description?.replaceAll('"', '""') ?? '';
      buffer.writeln('$date,${e.category},"$desc",${e.amount}');
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/expenses_export.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Expenses CSV Export');
  }

  // Export to PDF and open/share
  Future<void> _exportPdf(List<Expense> list, AppThemeColors colors) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Personal Ledger — Expenses Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Category', 'Description', 'Amount (INR)'],
                data: list.map((e) => [
                  DateFormat('yyyy-MM-dd').format(e.expenseDate),
                  e.category,
                  e.description ?? '',
                  'Rs. ${e.amount.toStringAsFixed(2)}'
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
    final file = File('${directory.path}/expenses_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainLedgerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final colors = AppTheme.expensesColors;

    final userId = authVm.currentUser?.id ?? '';
    final expenseList = vm.filteredExpenses;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics Header mimicking the web app - Scrollable horizontally
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                StatCard(
                  label: "Expenses — This Month",
                  value: "₹${vm.monthExpensesTotal.toStringAsFixed(2)}",
                  isPositive: false,
                  colors: colors,
                  width: 145,
                ),
                const SizedBox(width: 8),
                StatCard(
                  label: "Income — This Month",
                  value: "₹${vm.monthIncomeTotal.toStringAsFixed(2)}",
                  isPositive: true,
                  colors: colors,
                  width: 145,
                ),
                const SizedBox(width: 8),
                StatCard(
                  label: "Net — This Month",
                  value: "₹${vm.monthNetTotal.toStringAsFixed(2)}",
                  isPositive: vm.monthNetTotal >= 0,
                  colors: colors,
                  width: 145,
                ),
              ],
            ),
          ),
  
          // Add/Edit Expense Form Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _editingExpense != null ? 'Edit expense' : 'Add an expense',
                        style: AppTheme.getSubHeadingStyle(colors, size: 16),
                      ),
                      if (_editingExpense == null)
                        TextButton.icon(
                          onPressed: _isOcrLoading ? null : () => _showScanOptions(context),
                          icon: Icon(Icons.camera_alt_outlined, size: 18, color: _isOcrLoading ? Colors.grey : colors.ink),
                          label: Text(
                            "Scan Receipt",
                            style: AppTheme.getBodyStyle(colors, size: 12, weight: FontWeight.w600).copyWith(
                              color: colors.ink,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
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
                          label: "Category",
                          value: _selectedCategory,
                          items: _categories.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
                          },
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: "Note",
                          placeholder: "Optional note",
                          controller: _descController,
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_editingExpense != null) ...[
                        AppButton(
                          text: "Cancel",
                          isPrimary: false,
                          colors: colors,
                          onPressed: _exitEditMode,
                        ),
                        const SizedBox(width: 12),
                      ],
                      AppButton(
                        text: _editingExpense != null ? "Update entry" : "Add entry",
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
                          value: vm.expenseMonthFilter,
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All months')),
                            ...vm.expenseMonths.map((m) {
                              final date = DateTime.parse('$m-01');
                              final label = DateFormat('MMMM yyyy').format(date);
                              return DropdownMenuItem(value: m, child: Text(label));
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) vm.setExpenseMonthFilter(val);
                          },
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDropdownField<String>(
                          label: "Category Filter",
                          value: vm.expenseCategoryFilter,
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All categories')),
                            ...vm.expenseCategories.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) vm.setExpenseCategoryFilter(val);
                          },
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) => vm.setExpenseSearch(val),
                    decoration: InputDecoration(
                      hintText: "Search notes or categories...",
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
  
          // Toolbar for Exports
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  text: "Export CSV",
                  isGhost: true,
                  colors: colors,
                  onPressed: () => _exportExcel(expenseList),
                ),
                const SizedBox(width: 8),
                AppButton(
                  text: "Export PDF",
                  isGhost: true,
                  colors: colors,
                  onPressed: () => _exportPdf(expenseList, colors),
                ),
              ],
            ),
          ),
  
          // List of entries
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: expenseList.length,
            itemBuilder: (context, index) {
              final e = expenseList[index];
              final dateStr = DateFormat('yyyy-MM-dd').format(e.expenseDate);
  
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
                      Expanded(
                        child: Text(
                          e.category,
                          style: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "₹${e.amount.toStringAsFixed(2)}",
                        style: AppTheme.getMonoStyle(colors, size: 14, weight: FontWeight.w600).copyWith(
                          color: colors.red,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.description != null && e.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.description!,
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
                        onPressed: () => _enterEditMode(e),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 18, color: colors.red),
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
}
