import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../view_models/main_ledger_view_model.dart';
import '../../../data/models.dart';
import '../../core/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// BentoExpenseChartView
///
/// Pictorial visual expense analytics screen with dual filter modes:
///   1. "By Month": Filter by specific month with Bento Category Tiles.
///   2. "By Category": Filter by selected category over N months (e.g. Last 2, 3, 6, 12 months)
///      with multi-month visual color-coded tiles (every month gets a different color)
///      and itemized transaction history.
/// ─────────────────────────────────────────────────────────────────────────

enum ChartFilterMode { byMonth, byCategory }

class BentoExpenseChartView extends StatefulWidget {
  const BentoExpenseChartView({super.key});

  @override
  State<BentoExpenseChartView> createState() => _BentoExpenseChartViewState();
}

class _BentoExpenseChartViewState extends State<BentoExpenseChartView> {
  ChartFilterMode _filterMode = ChartFilterMode.byMonth;
  late DateTime _selectedMonth;

  // Category mode filters
  String _selectedCategory = 'Food';
  int _selectedDurationMonths = 2; // Default: Last 2 Months

  static const List<int> _durationOptions = [2, 3, 6, 12];

  // Distinct color palette for months in Category Trend view
  static const List<List<Color>> _monthColorGradients = [
    [Color(0xFF1E88E5), Color(0xFF42A5F5)], // Blue
    [Color(0xFFE53935), Color(0xFFEF5350)], // Red / Coral
    [Color(0xFF43A047), Color(0xFF66BB6A)], // Green
    [Color(0xFFFB8C00), Color(0xFFFFA726)], // Orange
    [Color(0xFF8E24AA), Color(0xFFAB47BC)], // Purple
    [Color(0xFF00ACC1), Color(0xFF26C6DA)], // Teal
    [Color(0xFF3949AB), Color(0xFF5C6BC0)], // Indigo
    [Color(0xFFD81B60), Color(0xFFEC407A)], // Pink
    [Color(0xFFF9A825), Color(0xFFFBC02D)], // Amber
    [Color(0xFF00897B), Color(0xFF26A69A)], // Emerald
    [Color(0xFF6D4C41), Color(0xFF8D6E63)], // Brown
    [Color(0xFF546E7A), Color(0xFF78909C)], // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainLedgerViewModel>();
    final colors = AppTheme.chartsColors;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Switcher Tab (By Month | By Category)
            _buildModeSwitcher(colors),
            const SizedBox(height: 10),

            if (_filterMode == ChartFilterMode.byMonth) ...[
              // Mode 1: BY MONTH
              _buildByMonthSection(vm, currencyFormat, colors),
            ] else ...[
              // Mode 2: BY CATEGORY (Multi-month breakdown)
              _buildByCategorySection(vm, currencyFormat, colors),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Segmented pill switcher: [ 📅 By Month ] | [ 🏷️ By Category ]
  Widget _buildModeSwitcher(AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.paperLine.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              title: "By Month",
              icon: Icons.calendar_month_outlined,
              isSelected: _filterMode == ChartFilterMode.byMonth,
              colors: colors,
              onTap: () => setState(() => _filterMode = ChartFilterMode.byMonth),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeButton(
              title: "By Category",
              icon: Icons.category_outlined,
              isSelected: _filterMode == ChartFilterMode.byCategory,
              colors: colors,
              onTap: () => setState(() => _filterMode = ChartFilterMode.byCategory),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : colors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTheme.getBodyStyle(colors, size: 12.5, weight: FontWeight.w700).copyWith(
                color: isSelected ? Colors.white : colors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MODE 1: BY MONTH
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildByMonthSection(
    MainLedgerViewModel vm,
    NumberFormat currencyFormat,
    AppThemeColors colors,
  ) {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    final monthExpenses = vm.allExpenses.where((e) {
      return DateFormat('yyyy-MM').format(e.expenseDate) == monthKey;
    }).toList();

    final Map<String, double> categoryTotals = {};
    double totalMonthAmount = 0.0;

    for (final exp in monthExpenses) {
      final cat = exp.category.trim().isNotEmpty ? exp.category.trim() : 'Others';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + exp.amount;
      totalMonthAmount += exp.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Month Selector & Total Amount Header Bar
        _buildMonthHeader(monthLabel, totalMonthAmount, currencyFormat, colors),
        const SizedBox(height: 14),

        if (totalMonthAmount <= 0)
          _buildEmptyState("No Expenses in $monthLabel", "Expenses added or scanned for this month will appear here in the visual bento chart.", colors)
        else ...[
          // Bento / Treemap Visual Grid
          _buildBentoGrid(sortedCategories, totalMonthAmount, currencyFormat),
          const SizedBox(height: 20),

          // Category Percentage Breakdown List
          _buildBreakdownList(sortedCategories, totalMonthAmount, currencyFormat, colors),
        ],
      ],
    );
  }

  Widget _buildMonthHeader(
    String monthLabel,
    double totalAmount,
    NumberFormat currencyFormat,
    AppThemeColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.paperLine.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: colors.ink,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              monthLabel,
              style: AppTheme.getSubHeadingStyle(colors, size: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: colors.ink,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              currencyFormat.format(totalAmount),
              style: AppTheme.getMonoStyle(colors, size: 15, weight: FontWeight.w700).copyWith(
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MODE 2: BY CATEGORY (Multi-Month Breakdown & Different Color per Month)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildByCategorySection(
    MainLedgerViewModel vm,
    NumberFormat currencyFormat,
    AppThemeColors colors,
  ) {
    final availableCategories = vm.expenseCategories;
    if (!availableCategories.contains(_selectedCategory) && availableCategories.isNotEmpty) {
      _selectedCategory = availableCategories.first;
    }

    // Determine the cutoff date based on duration
    final now = DateTime.now();
    final startOfCurrentMonth = DateTime(now.year, now.month, 1);
    final cutoffDate = DateTime(startOfCurrentMonth.year, startOfCurrentMonth.month - (_selectedDurationMonths - 1), 1);

    // Filter matching expenses for the category in the duration
    final categoryExpenses = vm.allExpenses.where((e) {
      final matchesCategory = e.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase();
      final isWithinTimeframe = e.expenseDate.isAfter(cutoffDate.subtract(const Duration(days: 1)));
      return matchesCategory && isWithinTimeframe;
    }).toList();

    // Group spending by month
    final Map<String, List<Expense>> monthlyGroups = {};
    final Map<String, double> monthlyTotals = {};
    double totalCategoryAmount = 0.0;

    // Generate list of months in chronological order for the selected range
    for (int i = _selectedDurationMonths - 1; i >= 0; i--) {
      final mDate = DateTime(startOfCurrentMonth.year, startOfCurrentMonth.month - i, 1);
      final mKey = DateFormat('yyyy-MM').format(mDate);
      monthlyGroups[mKey] = [];
      monthlyTotals[mKey] = 0.0;
    }

    for (final exp in categoryExpenses) {
      final mKey = DateFormat('yyyy-MM').format(exp.expenseDate);
      if (monthlyGroups.containsKey(mKey)) {
        monthlyGroups[mKey]!.add(exp);
        monthlyTotals[mKey] = (monthlyTotals[mKey] ?? 0.0) + exp.amount;
        totalCategoryAmount += exp.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter controls (Category dropdown + Duration pill selector)
        _buildCategoryFilterControls(availableCategories, colors),
        const SizedBox(height: 12),

        // Total spending summary banner
        _buildCategorySummaryBanner(_selectedCategory, _selectedDurationMonths, totalCategoryAmount, currencyFormat, colors),
        const SizedBox(height: 14),

        if (totalCategoryAmount <= 0)
          _buildEmptyState(
            "No $_selectedCategory Expenses",
            "No expenses recorded for $_selectedCategory in the last $_selectedDurationMonths months.",
            colors,
          )
        else ...[
          // Multi-Month Bento Grid: Every month gets a distinct color!
          _buildMultiMonthBentoGrid(monthlyTotals, totalCategoryAmount, currencyFormat),
          const SizedBox(height: 20),

          // Monthly Breakdown & Itemized Transactions List
          _buildMonthlyTransactionsList(monthlyGroups, monthlyTotals, totalCategoryAmount, currencyFormat, colors),
        ],
      ],
    );
  }

  /// Category Dropdown and Duration Pill Selector
  Widget _buildCategoryFilterControls(List<String> categories, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.paperLine.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SELECT CATEGORY",
                      style: AppTheme.getMonoStyle(colors, size: 10.5, weight: FontWeight.w700).copyWith(
                        color: colors.brassDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: categories.contains(_selectedCategory)
                          ? _selectedCategory
                          : (categories.isNotEmpty ? categories.first : null),
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.paperLine),
                        ),
                        filled: true,
                        fillColor: colors.paper.withValues(alpha: 0.4),
                      ),
                      style: AppTheme.getBodyStyle(colors, size: 13.5, weight: FontWeight.w700),
                      items: categories.map((cat) {
                        final config = _getCategoryVisualConfig(cat);
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(config.icon, color: config.primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Text(cat),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),

                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Duration Pills (Last 2m, Last 3m, Last 6m, Last 12m)
          Row(
            children: [
              Text(
                "TIMEFRAME:",
                style: AppTheme.getMonoStyle(colors, size: 10.5, weight: FontWeight.w700).copyWith(
                  color: colors.brassDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _durationOptions.map((months) {
                    final isSel = _selectedDurationMonths == months;
                    return InkWell(
                      onTap: () => setState(() => _selectedDurationMonths = months),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? colors.ink : colors.paper.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSel ? colors.ink : colors.paperLine,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "${months}M",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : colors.inkSoft,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Summary Banner for By-Category Mode
  Widget _buildCategorySummaryBanner(
    String category,
    int durationMonths,
    double totalAmount,
    NumberFormat currencyFormat,
    AppThemeColors colors,
  ) {
    final config = _getCategoryVisualConfig(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.primaryColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: config.primaryColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$category Expenses (Last $durationMonths Months)",
                  style: AppTheme.getBodyStyle(colors, size: 12.5, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Total Spent in Period",
                  style: AppTheme.getBodyStyle(colors, soft: true, size: 11),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(totalAmount),
            style: AppTheme.getMonoStyle(colors, size: 16, weight: FontWeight.w800).copyWith(
              color: config.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Multi-Month Bento Grid: Every month gets a distinct color!
  Widget _buildMultiMonthBentoGrid(
    Map<String, double> monthlyTotals,
    double totalAmount,
    NumberFormat currencyFormat,
  ) {
    final activeMonths = monthlyTotals.entries.where((e) => e.value > 0).toList();
    if (activeMonths.isEmpty) return const SizedBox.shrink();

    final List<_CategoryTileData> monthTiles = [];

    for (int i = 0; i < activeMonths.length; i++) {
      final entry = activeMonths[i];
      final monthDate = DateTime.parse("${entry.key}-01");
      final monthFormatted = DateFormat('MMMM yyyy').format(monthDate);
      final double percentage = (entry.value / totalAmount) * 100.0;

      // Assign a unique gradient for every month
      final gradientColors = _monthColorGradients[i % _monthColorGradients.length];

      monthTiles.add(_CategoryTileData(
        category: monthFormatted,
        amount: entry.value,
        percentage: percentage,
        config: _CategoryVisualConfig(
          primaryColor: gradientColors[0],
          secondaryColor: gradientColors[1],
          icon: Icons.calendar_today_rounded,
        ),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: _assembleBentoRows(monthTiles, currencyFormat),
        ),
      ),
    );
  }

  /// Itemized monthly breakdown and transactions
  Widget _buildMonthlyTransactionsList(
    Map<String, List<Expense>> monthlyGroups,
    Map<String, double> monthlyTotals,
    double totalAmount,
    NumberFormat currencyFormat,
    AppThemeColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.paperLine.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              "MONTH-BY-MONTH BREAKDOWN",
              style: AppTheme.getMonoStyle(colors, size: 11, weight: FontWeight.w700).copyWith(
                color: colors.brassDark,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Divider(height: 12),
          ...monthlyGroups.entries.map((entry) {
            final monthDate = DateTime.parse("${entry.key}-01");
            final monthName = DateFormat('MMMM yyyy').format(monthDate);
            final monthTotal = monthlyTotals[entry.key] ?? 0.0;
            final double percent = totalAmount > 0 ? (monthTotal / totalAmount) * 100.0 : 0.0;
            final expenses = entry.value;

            final int monthIndex = monthlyGroups.keys.toList().indexOf(entry.key);
            final gradient = _monthColorGradients[monthIndex % _monthColorGradients.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.paper.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.paperLine.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Month Header Row
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: gradient[0],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          monthName,
                          style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradient[0].withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${percent.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: gradient[0],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyFormat.format(monthTotal),
                        style: AppTheme.getMonoStyle(colors, size: 13, weight: FontWeight.w800).copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),

                  if (expenses.isNotEmpty) ...[
                    const Divider(height: 10),
                    ...expenses.map((exp) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM').format(exp.expenseDate),
                              style: AppTheme.getBodyStyle(colors, soft: true, size: 11.5),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                exp.description?.isNotEmpty == true ? exp.description! : exp.category,
                                style: AppTheme.getBodyStyle(colors, size: 12, weight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              currencyFormat.format(exp.amount),
                              style: AppTheme.getMonoStyle(colors, size: 12, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SHARED BENTO GRID BUILDERS & VISUAL HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildBentoGrid(
    List<MapEntry<String, double>> sortedCategories,
    double totalAmount,
    NumberFormat currencyFormat,
  ) {
    if (sortedCategories.isEmpty) return const SizedBox.shrink();

    final List<_CategoryTileData> tileDataList = sortedCategories.map((entry) {
      final config = _getCategoryVisualConfig(entry.key);
      final double percentage = (entry.value / totalAmount) * 100.0;
      return _CategoryTileData(
        category: entry.key,
        amount: entry.value,
        percentage: percentage,
        config: config,
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: _assembleBentoRows(tileDataList, currencyFormat),
        ),
      ),
    );
  }

  List<Widget> _assembleBentoRows(List<_CategoryTileData> tiles, NumberFormat currencyFormat) {
    final List<Widget> rows = [];
    int index = 0;

    while (index < tiles.length) {
      final remaining = tiles.length - index;

      if (remaining == 1) {
        rows.add(_buildSingleTileRow(tiles[index], currencyFormat));
        index += 1;
      } else if (remaining == 2) {
        rows.add(_buildTwoTileRow(tiles[index], tiles[index + 1], currencyFormat, ratio: 0.55));
        index += 2;
      } else if (remaining == 3) {
        rows.add(_buildTwoTileRow(tiles[index], tiles[index + 1], currencyFormat, ratio: 0.60));
        rows.add(_buildSingleTileRow(tiles[index + 2], currencyFormat));
        index += 3;
      } else {
        if (rows.length % 2 == 0) {
          rows.add(_buildTwoTileRow(tiles[index], tiles[index + 1], currencyFormat, ratio: 0.62));
        } else {
          rows.add(_buildTwoTileRow(tiles[index], tiles[index + 1], currencyFormat, ratio: 0.42));
        }
        index += 2;
      }
    }

    return rows;
  }

  Widget _buildSingleTileRow(_CategoryTileData tile, NumberFormat currencyFormat) {
    return Container(
      height: 130,
      margin: const EdgeInsets.only(bottom: 4),
      child: _BentoTileWidget(data: tile, currencyFormat: currencyFormat),
    );
  }

  Widget _buildTwoTileRow(
    _CategoryTileData left,
    _CategoryTileData right,
    NumberFormat currencyFormat, {
    required double ratio,
  }) {
    return Container(
      height: 138,
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: (ratio * 100).toInt(),
            child: _BentoTileWidget(data: left, currencyFormat: currencyFormat),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: ((1.0 - ratio) * 100).toInt(),
            child: _BentoTileWidget(data: right, currencyFormat: currencyFormat),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownList(
    List<MapEntry<String, double>> sortedCategories,
    double totalAmount,
    NumberFormat currencyFormat,
    AppThemeColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.paperLine.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              "CATEGORY BREAKDOWN",
              style: AppTheme.getMonoStyle(colors, size: 11, weight: FontWeight.w700).copyWith(
                color: colors.brassDark,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Divider(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCategories.length,
            separatorBuilder: (_, _) => const Divider(height: 10),
            itemBuilder: (context, i) {
              final entry = sortedCategories[i];
              final config = _getCategoryVisualConfig(entry.key);
              final double percent = (entry.value / totalAmount) * 100.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: config.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(config.icon, color: config.primaryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.key.toUpperCase(),
                              style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: config.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${percent.toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: config.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormat.format(entry.value),
                      style: AppTheme.getMonoStyle(colors, size: 13, weight: FontWeight.w700).copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.paperLine.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.paper,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 40, color: colors.inkSoft),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.getSubHeadingStyle(colors, size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  _CategoryVisualConfig _getCategoryVisualConfig(String category) {
    final normalized = category.toLowerCase().trim();

    if (normalized == 'food' || normalized.contains('restaurant') || normalized.contains('sweet')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF2E7D32),
        secondaryColor: Color(0xFF43A047),
        icon: Icons.restaurant_rounded,
      );
    }
    if (normalized == 'groceries' || normalized.contains('supermarket') || normalized.contains('kirana')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF558B2F),
        secondaryColor: Color(0xFF7CB342),
        icon: Icons.shopping_basket_rounded,
      );
    }
    if (normalized == 'fuel' || normalized.contains('petrol') || normalized.contains('diesel')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF0D47A1),
        secondaryColor: Color(0xFF1976D2),
        icon: Icons.local_gas_station_rounded,
      );
    }
    if (normalized == 'transport' || normalized.contains('travel') || normalized.contains('flight') || normalized.contains('cab')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF0288D1),
        secondaryColor: Color(0xFF29B6F6),
        icon: Icons.flight_takeoff_rounded,
      );
    }
    if (normalized.contains('electricity') || normalized.contains('power') || normalized.contains('tgspdcl')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF673AB7),
        secondaryColor: Color(0xFF7E57C2),
        icon: Icons.bolt_rounded,
      );
    }
    if (normalized.contains('mobile') || normalized.contains('wifi') || normalized.contains('broadband') || normalized.contains('jio') || normalized.contains('airtel')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF0097A7),
        secondaryColor: Color(0xFF00BCD4),
        icon: Icons.wifi_rounded,
      );
    }
    if (normalized.contains('utilities') || normalized.contains('water') || normalized.contains('gas')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF8E24AA),
        secondaryColor: Color(0xFFBA68C8),
        icon: Icons.receipt_long_rounded,
      );
    }
    if (normalized.contains('rent')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFFD84315),
        secondaryColor: Color(0xFFF4511E),
        icon: Icons.home_rounded,
      );
    }
    if (normalized == 'shopping' || normalized.contains('amazon') || normalized.contains('flipkart') || normalized.contains('cloth')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFFF57F17),
        secondaryColor: Color(0xFFFFB300),
        icon: Icons.shopping_bag_rounded,
      );
    }
    if (normalized == 'health' || normalized.contains('medical') || normalized.contains('pharmacy') || normalized.contains('hospital')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFFC2185B),
        secondaryColor: Color(0xFFE91E63),
        icon: Icons.local_hospital_rounded,
      );
    }
    if (normalized == 'entertainment' || normalized.contains('movie') || normalized.contains('cinema') || normalized.contains('pvr')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF512DA8),
        secondaryColor: Color(0xFF5C6BC0),
        icon: Icons.tv_rounded,
      );
    }
    if (normalized == 'adhoc' || normalized.contains('misc')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF37474F),
        secondaryColor: Color(0xFF546E7A),
        icon: Icons.tune_rounded,
      );
    }

    return const _CategoryVisualConfig(
      primaryColor: Color(0xFF5D4037),
      secondaryColor: Color(0xFF8D6E63),
      icon: Icons.category_rounded,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Helper Models & Widgets
/// ─────────────────────────────────────────────────────────────────────────

class _CategoryTileData {
  final String category;
  final double amount;
  final double percentage;
  final _CategoryVisualConfig config;

  _CategoryTileData({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.config,
  });
}

class _CategoryVisualConfig {
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;

  const _CategoryVisualConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
  });
}

class _BentoTileWidget extends StatelessWidget {
  final _CategoryTileData data;
  final NumberFormat currencyFormat;

  const _BentoTileWidget({
    required this.data,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.config.primaryColor,
            data.config.secondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                painter: _LeafPatternPainter(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      currencyFormat.format(data.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      data.config.icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${data.percentage.toStringAsFixed(0)}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeafPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.1, size.width, size.height * 0.5);
    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.2, size.height);
    path2.quadraticBezierTo(size.width * 0.7, size.height * 0.3, size.width, 0);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
