import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../view_models/main_ledger_view_model.dart';
import '../../core/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// BentoExpenseChartView
///
/// Pictorial visual expense analytics screen styled with an asymmetric
/// bento / treemap grid, month switcher, and sorted category percentage breakdown.
/// ─────────────────────────────────────────────────────────────────────────

class BentoExpenseChartView extends StatefulWidget {
  const BentoExpenseChartView({super.key});

  @override
  State<BentoExpenseChartView> createState() => _BentoExpenseChartViewState();
}

class _BentoExpenseChartViewState extends State<BentoExpenseChartView> {
  late DateTime _selectedMonth;

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

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    // Filter expenses for this selected month
    final monthExpenses = vm.allExpenses.where((e) {
      return DateFormat('yyyy-MM').format(e.expenseDate) == monthKey;
    }).toList();

    // Group and calculate totals by category
    final Map<String, double> categoryTotals = {};
    double totalMonthAmount = 0.0;

    for (final exp in monthExpenses) {
      final cat = exp.category.trim().isNotEmpty ? exp.category.trim() : 'Others';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + exp.amount;
      totalMonthAmount += exp.amount;
    }

    // Sort categories from highest spending to lowest
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Selector & Total Amount Header Bar
            _buildMonthHeader(monthLabel, totalMonthAmount, currencyFormat, colors),
            const SizedBox(height: 14),

            if (totalMonthAmount <= 0)
              _buildEmptyState(monthLabel, colors)
            else ...[
              // Bento / Treemap Visual Grid
              _buildBentoGrid(sortedCategories, totalMonthAmount, currencyFormat),
              const SizedBox(height: 20),

              // Category Percentage Breakdown List
              _buildBreakdownList(sortedCategories, totalMonthAmount, currencyFormat, colors),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Month selector with < Month Year > and total spending amount
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

  /// Dynamic Bento / Treemap grid showing color-coded category tiles
  Widget _buildBentoGrid(
    List<MapEntry<String, double>> sortedCategories,
    double totalAmount,
    NumberFormat currencyFormat,
  ) {
    if (sortedCategories.isEmpty) return const SizedBox.shrink();

    // Map each category to its styled tile
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

  /// Assembles tiles into aesthetic asymmetric Bento rows
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
        // 4 or more tiles: alternating 2-column asymmetric layouts
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

  /// Breakdown list beneath the Bento Grid
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
                    // Category Icon
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

                    // Category Name & Percentage
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

                    // Category Amount
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

  Widget _buildEmptyState(String monthLabel, AppThemeColors colors) {
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
            "No Expenses in $monthLabel",
            style: AppTheme.getSubHeadingStyle(colors, size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Expenses added or scanned for this month will appear here in the visual bento chart.",
            style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Distinct, unique color palettes and vector icons for every single category
  _CategoryVisualConfig _getCategoryVisualConfig(String category) {
    final normalized = category.toLowerCase().trim();

    // 1. Food: Deep Forest Green
    if (normalized == 'food' || normalized.contains('restaurant') || normalized.contains('sweet')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF2E7D32),
        secondaryColor: Color(0xFF43A047),
        icon: Icons.restaurant_rounded,
      );
    }

    // 2. Groceries: Fresh Olive / Lime Green
    if (normalized == 'groceries' || normalized.contains('supermarket') || normalized.contains('kirana')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF558B2F),
        secondaryColor: Color(0xFF7CB342),
        icon: Icons.shopping_basket_rounded,
      );
    }

    // 3. Fuel: Marine / Royal Blue
    if (normalized == 'fuel' || normalized.contains('petrol') || normalized.contains('diesel')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF0D47A1),
        secondaryColor: Color(0xFF1976D2),
        icon: Icons.local_gas_station_rounded,
      );
    }

    // 4. Transport: Sky / Cerulean Blue
    if (normalized == 'transport' || normalized.contains('travel') || normalized.contains('flight') || normalized.contains('cab')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF0288D1),
        secondaryColor: Color(0xFF29B6F6),
        icon: Icons.flight_takeoff_rounded,
      );
    }

    // 5. Electricity Bills: Electric Violet / Indigo
    if (normalized.contains('electricity') || normalized.contains('power') || normalized.contains('tgspdcl')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF673AB7),
        secondaryColor: Color(0xFF7E57C2),
        icon: Icons.bolt_rounded,
      );
    }

    // 6. Mobile / Wifi Bills: Cyan / Ocean Teal
    if (normalized.contains('mobile') || normalized.contains('wifi') || normalized.contains('broadband') || normalized.contains('jio') || normalized.contains('airtel')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF0097A7),
        secondaryColor: Color(0xFF00BCD4),
        icon: Icons.wifi_rounded,
      );
    }

    // 7. Bills / Utilities: Rich Purple / Orchid
    if (normalized.contains('utilities') || normalized.contains('water') || normalized.contains('gas')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF8E24AA),
        secondaryColor: Color(0xFFBA68C8),
        icon: Icons.receipt_long_rounded,
      );
    }

    // 8. Rent: Warm Terracotta / Rust Orange
    if (normalized.contains('rent')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFFD84315),
        secondaryColor: Color(0xFFF4511E),
        icon: Icons.home_rounded,
      );
    }

    // 9. Shopping: Radiant Amber / Gold
    if (normalized == 'shopping' || normalized.contains('amazon') || normalized.contains('flipkart') || normalized.contains('cloth')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFFF57F17),
        secondaryColor: Color(0xFFFFB300),
        icon: Icons.shopping_bag_rounded,
      );
    }

    // 10. Health: Ruby / Crimson Rose
    if (normalized == 'health' || normalized.contains('medical') || normalized.contains('pharmacy') || normalized.contains('hospital')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFFC2185B),
        secondaryColor: Color(0xFFE91E63),
        icon: Icons.local_hospital_rounded,
      );
    }

    // 11. Entertainment: Grape / Deep Lavender
    if (normalized == 'entertainment' || normalized.contains('movie') || normalized.contains('cinema') || normalized.contains('pvr')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF512DA8),
        secondaryColor: Color(0xFF5C6BC0),
        icon: Icons.tv_rounded,
      );
    }

    // 12. Adhoc: Steel Slate / Charcoal
    if (normalized == 'adhoc' || normalized.contains('misc')) {
      return const _CategoryVisualConfig(
        primaryColor: Color(0xFF37474F),
        secondaryColor: Color(0xFF546E7A),
        icon: Icons.tune_rounded,
      );
    }

    // 13. Others / Fallback: Warm Mocha / Bronze
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
          // Background organic subtle leaf pattern overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                painter: _LeafPatternPainter(),
              ),
            ),
          ),

          // Tile Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Category Name + Amount below it
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

                // Center Icon with soft emboss glow
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

                // Bottom Right: Percentage Badge
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

/// Subtle decorative botanical leaf pattern matching the reference image texture
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
