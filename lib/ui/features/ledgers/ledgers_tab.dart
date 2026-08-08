import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../view_models/ledger_view_model.dart';
import '../../../view_models/auth_view_model.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'ledger_detail_view.dart';

class LedgersTab extends StatefulWidget {
  const LedgersTab({super.key});

  @override
  State<LedgersTab> createState() => _LedgersTabState();
}

class _LedgersTabState extends State<LedgersTab> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LedgerViewModel>().loadLedgers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createLedger(LedgerViewModel vm, String userId) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your ledger a name.')),
      );
      return;
    }

    try {
      await vm.addLedger(name, userId);
      if (!mounted) return;
      _nameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ledger created successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create ledger: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final colors = AppTheme.ledgersColors;
    final userId = authVm.currentUser?.id ?? '';

    return RefreshIndicator(
      onRefresh: () => vm.loadLedgers(),
      color: colors.ink,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description banner card mimicking .entry-card info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(colors),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's a custom ledger?",
                      style: AppTheme.getSubHeadingStyle(colors, size: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "A separate book for a specific area of your life — like Agriculture or Education — with its own categories and its own totals. Entries here never mix into your main Expenses/Income numbers.",
                      style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                    ),
                  ],
                ),
              ),
            ),
    
            // Create Ledger Form Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(colors),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: "Name",
                      placeholder: "e.g. Agriculture, Education, Rental Property",
                      controller: _nameController,
                      colors: colors,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        AppButton(
                          text: "Create ledger",
                          isLoading: vm.isLoading,
                          colors: colors,
                          onPressed: () => _createLedger(vm, userId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    
            const SizedBox(height: 16),
    
            // Header Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Your ledgers",
                  style: AppTheme.getSubHeadingStyle(colors, size: 18),
                ),
              ),
            ),
    
            const SizedBox(height: 10),
    
            // Ledgers List
            vm.ledgers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        "No custom ledgers yet — create one above.",
                        style: AppTheme.getBodyStyle(colors, soft: true, size: 14, weight: FontWeight.w500),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: vm.ledgers.length,
                    itemBuilder: (context, index) {
                      final wl = vm.ledgers[index];
    
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: colors.paperLine),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wl.ledger.name,
                                      style: AppTheme.getSubHeadingStyle(colors, size: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Income ₹${wl.totalIncome.toStringAsFixed(2)} · Expenses ₹${wl.totalExpense.toStringAsFixed(2)}",
                                      style: AppTheme.getMonoStyle(colors, size: 12).copyWith(
                                        color: colors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  AppButton(
                                    text: "Open",
                                    isPrimary: false,
                                    colors: colors,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LedgerDetailView(
                                            ledger: wl.ledger,
                                          ),
                                        ),
                                      ).then((_) {
                                        vm.loadLedgers();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 20, color: colors.red),
                                    onPressed: () async {
                                      final confirm = await showConfirmDialog(
                                        context: context,
                                        title: 'Delete "${wl.ledger.name}"?',
                                        content: "This permanently deletes every entry and category in it. This cannot be undone.",
                                        colors: colors,
                                      );
                                      if (confirm == true) {
                                        vm.deleteLedger(wl.ledger.id);
                                      }
                                    },
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
      ),
    );
  }
}
