import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../../data/models.dart';
import '../../../data/services/gemini_advisor_service.dart';
import '../../../view_models/main_ledger_view_model.dart';
import '../../../view_models/recurring_view_model.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class AiAdvisorTab extends StatefulWidget {
  const AiAdvisorTab({super.key});

  @override
  State<AiAdvisorTab> createState() => _AiAdvisorTabState();
}

class _AiAdvisorTabState extends State<AiAdvisorTab> {
  String _selectedPeriod = '3m';
  bool _isLoading = false;
  FinancialAdvisoryReport? _report;
  Map<String, double>? _categoryData;
  String? _errorMessage;

  final GeminiAdvisorService _advisorService = GeminiAdvisorService();

  final List<Color> _chartColors = [
    const Color(0xFF2E7D32),
    const Color(0xFF0D47A1),
    const Color(0xFFE65100),
    const Color(0xFF6A1B9A),
    const Color(0xFF00838F),
    const Color(0xFFC2185B),
    const Color(0xFF455A64),
    const Color(0xFFF9A825),
    const Color(0xFF1565C0),
    const Color(0xFF558B2F),
  ];

  String _getPeriodLabel(String periodKey) {
    switch (periodKey) {
      case '1m':
        return 'Last 1 Month';
      case '3m':
        return 'Last 3 Months';
      case '6m':
        return 'Last 6 Months';
      case '12m':
        return 'Last 12 Months';
      default:
        return 'Selected Period';
    }
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _isLoading = true;
      _report = null;
      _categoryData = null;
      _errorMessage = null;
    });

    try {
      final ledgerVm = context.read<MainLedgerViewModel>();
      final recurringVm = context.read<RecurringViewModel>();

      // Compute cutoff date
      final now = DateTime.now();
      int monthsBack = 3;
      if (_selectedPeriod == '1m') monthsBack = 1;
      if (_selectedPeriod == '3m') monthsBack = 3;
      if (_selectedPeriod == '6m') monthsBack = 6;
      if (_selectedPeriod == '12m') monthsBack = 12;

      final cutoffDate = DateTime(now.year, now.month - (monthsBack - 1), 1);

      // Filter expenses & income
      final periodExpenses = ledgerVm.allExpenses.where((e) {
        return e.expenseDate.isAfter(cutoffDate.subtract(const Duration(days: 1)));
      }).toList();

      final periodIncome = ledgerVm.allIncome.where((i) {
        return i.incomeDate.isAfter(cutoffDate.subtract(const Duration(days: 1)));
      }).toList();

      double totalExpenses = 0.0;
      final Map<String, double> categoryTotals = {};
      for (final exp in periodExpenses) {
        final cat = exp.category.trim().isNotEmpty ? exp.category.trim() : 'Others';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + exp.amount;
        totalExpenses += exp.amount;
      }

      double totalIncome = 0.0;
      for (final inc in periodIncome) {
        totalIncome += inc.amount;
      }

      final report = await _advisorService.generateAdvisory(
        periodLabel: _getPeriodLabel(_selectedPeriod),
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        categoryTotals: categoryTotals,
        periodExpenses: periodExpenses,
        periodIncome: periodIncome,
        recurringTemplates: recurringVm.recurringExpenses,
      );

      setState(() {
        _report = report;
        _categoryData = categoryTotals;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.insightsColors;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Control Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(colors),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.auto_awesome_rounded, color: colors.brassDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI Financial Health Advisor",
                            style: AppTheme.getSubHeadingStyle(colors, size: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Powered by Google Gemini Financial Intelligence",
                            style: AppTheme.getBodyStyle(colors, soft: true, size: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Analyzes your spending patterns, fixed commitments, and savings rate to provide a Certified Financial Planner (CFP) diagnostic report.",
                  style: AppTheme.getBodyStyle(colors, soft: true, size: 12.5),
                ),
                const SizedBox(height: 16),

                // Range toggles
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodPill('1m', '1 Month', colors),
                      const SizedBox(width: 6),
                      _buildPeriodPill('3m', '3 Months', colors),
                      const SizedBox(width: 6),
                      _buildPeriodPill('6m', '6 Months', colors),
                      const SizedBox(width: 6),
                      _buildPeriodPill('12m', '1 Year', colors),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                AppButton(
                  text: "Run Financial Health Audit",
                  isLoading: _isLoading,
                  colors: colors,
                  onPressed: _runAnalysis,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: AppTheme.getBodyStyle(colors, size: 13).copyWith(color: colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Loading State
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                children: [
                  CircularProgressIndicator(color: colors.ink),
                  const SizedBox(height: 16),
                  Text(
                    "Analyzing cash flows, budgeting ratios & spending trends...",
                    style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_report != null) ...[
            // 1. Executive Health Score Banner
            _buildExecutiveHealthBanner(_report!, colors),
            const SizedBox(height: 16),

            // 2. 50/30/20 Budgeting Rule Analyzer
            _buildBudgetRuleCard(_report!, colors),
            const SizedBox(height: 16),

            // 3. Category Breakdown Pie Chart
            if (_categoryData != null && _categoryData!.isNotEmpty) ...[
              _buildCategoryChartCard(_categoryData!, colors, currencyFormat),
              const SizedBox(height: 16),
            ],

            // 4. Key Observations Card
            if (_report!.keyObservations.isNotEmpty) ...[
              _buildKeyObservationsCard(_report!.keyObservations, colors),
              const SizedBox(height: 16),
            ],

            // 5. Actionable Cost-Cutting Levers
            if (_report!.actionItems.isNotEmpty) ...[
              _buildActionItemsCard(_report!.actionItems, colors),
              const SizedBox(height: 16),
            ],

            // 6. Recommended Next Month Category Budgets
            if (_report!.recommendedCategoryBudgets.isNotEmpty) ...[
              _buildRecommendedBudgetsCard(_report!.recommendedCategoryBudgets, colors, currencyFormat),
              const SizedBox(height: 16),
            ],

            // 7. Full CFP Diagnostic Report (Markdown)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: colors.brassDark, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Detailed Advisory Report",
                        style: AppTheme.getSubHeadingStyle(colors, size: 15),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  MarkdownBody(
                    data: _report!.fullMarkdown,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTheme.getBodyStyle(colors, size: 13.5),
                      h1: AppTheme.getSubHeadingStyle(colors, size: 19),
                      h2: AppTheme.getSubHeadingStyle(colors, size: 16),
                      h3: AppTheme.getSubHeadingStyle(colors, size: 14.5),
                      listBullet: AppTheme.getBodyStyle(colors, size: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Generated automatically by Google Gemini using your logged transactions — not formal legal financial advice.",
              style: AppTheme.getBodyStyle(colors, soft: true, size: 11),
              textAlign: TextAlign.center,
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.cardDecoration(colors),
              child: Column(
                children: [
                  Icon(Icons.analytics_outlined, size: 48, color: colors.inkSoft.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(
                    "Ready for Financial Audit",
                    style: AppTheme.getSubHeadingStyle(colors, size: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Select a time range above and tap 'Run Financial Health Audit' to generate a comprehensive spending analysis and cost-cutting plan.",
                    style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodPill(String periodKey, String label, AppThemeColors colors) {
    final isSel = _selectedPeriod == periodKey;
    return InkWell(
      onTap: () => setState(() => _selectedPeriod = periodKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? colors.ink : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? colors.ink : colors.paperLine,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.getBodyStyle(colors, size: 12, weight: isSel ? FontWeight.w700 : FontWeight.w500).copyWith(
            color: isSel ? Colors.white : colors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveHealthBanner(FinancialAdvisoryReport report, AppThemeColors colors) {
    Color scoreColor;
    IconData scoreIcon;

    switch (report.healthScore.toLowerCase()) {
      case 'excellent':
        scoreColor = const Color(0xFF2E7D32);
        scoreIcon = Icons.verified_rounded;
        break;
      case 'good':
        scoreColor = const Color(0xFF00897B);
        scoreIcon = Icons.thumb_up_alt_rounded;
        break;
      case 'fair':
        scoreColor = const Color(0xFFF57C00);
        scoreIcon = Icons.info_rounded;
        break;
      default:
        scoreColor = const Color(0xFFD32F2F);
        scoreIcon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "FINANCIAL HEALTH STATUS",
                style: AppTheme.getMonoStyle(colors, size: 10.5, weight: FontWeight.w700).copyWith(
                  color: colors.brassDark,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(scoreIcon, color: scoreColor, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      report.healthScore.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.executiveSummary,
            style: AppTheme.getBodyStyle(colors, size: 13.5, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRuleCard(FinancialAdvisoryReport report, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "50 / 30 / 20 Budgeting Rule",
                style: AppTheme.getSubHeadingStyle(colors, size: 15),
              ),
              Text(
                "Target vs Actual",
                style: AppTheme.getBodyStyle(colors, soft: true, size: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  Expanded(
                    flex: report.needsPercent.clamp(1, 100).toInt(),
                    child: Container(color: const Color(0xFF2E7D32)),
                  ),
                  Expanded(
                    flex: report.wantsPercent.clamp(1, 100).toInt(),
                    child: Container(color: const Color(0xFFF57C00)),
                  ),
                  Expanded(
                    flex: report.savingsPercent.clamp(0, 100).toInt(),
                    child: Container(color: const Color(0xFF1976D2)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Breakdown Legends
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBudgetLegend(
                label: "Needs (Target 50%)",
                actualPercent: report.needsPercent,
                color: const Color(0xFF2E7D32),
                colors: colors,
              ),
              _buildBudgetLegend(
                label: "Wants (Target 30%)",
                actualPercent: report.wantsPercent,
                color: const Color(0xFFF57C00),
                colors: colors,
              ),
              _buildBudgetLegend(
                label: "Savings (Target 20%)",
                actualPercent: report.savingsPercent,
                color: const Color(0xFF1976D2),
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetLegend({
    required String label,
    required double actualPercent,
    required Color color,
    required AppThemeColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(
              "${actualPercent.toStringAsFixed(0)}%",
              style: AppTheme.getMonoStyle(colors, size: 12, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.getBodyStyle(colors, soft: true, size: 10),
        ),
      ],
    );
  }

  Widget _buildCategoryChartCard(Map<String, double> data, AppThemeColors colors, NumberFormat format) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final double total = sorted.fold(0.0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Category Spending Breakdown",
            style: AppTheme.getSubHeadingStyle(colors, size: 15),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _buildChartSections(sorted),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: _buildChartLegend(sorted, total, format),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(List<MapEntry<String, double>> data) {
    final List<PieChartSectionData> sections = [];
    int i = 0;

    for (final entry in data) {
      final color = _chartColors[i % _chartColors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          title: '₹${entry.value.toStringAsFixed(0)}',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      i++;
    }

    return sections;
  }

  List<Widget> _buildChartLegend(List<MapEntry<String, double>> data, double total, NumberFormat format) {
    final List<Widget> legend = [];
    int i = 0;

    for (final entry in data) {
      final color = _chartColors[i % _chartColors.length];
      final double pct = total > 0 ? (entry.value / total) * 100.0 : 0.0;
      legend.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              "${entry.key} (${pct.toStringAsFixed(0)}%): ${format.format(entry.value)}",
              style: AppTheme.getBodyStyle(AppTheme.insightsColors, size: 11, soft: true),
            ),
          ],
        ),
      );
      i++;
    }

    return legend;
  }

  Widget _buildKeyObservationsCard(List<String> observations, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: colors.brassDark, size: 20),
              const SizedBox(width: 8),
              Text(
                "Key Spending Observations",
                style: AppTheme.getSubHeadingStyle(colors, size: 15),
              ),
            ],
          ),
          const Divider(height: 16),
          ...observations.map((obs) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: colors.ink, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      obs,
                      style: AppTheme.getBodyStyle(colors, size: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionItemsCard(List<String> actions, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
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
              Icon(Icons.tips_and_updates_rounded, color: const Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Text(
                "Recommended Cost-Cutting Levers",
                style: AppTheme.getSubHeadingStyle(colors, size: 15).copyWith(
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...actions.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final text = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$idx",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendedBudgetsCard(Map<String, double> budgets, AppThemeColors colors, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, color: colors.brassDark, size: 20),
              const SizedBox(width: 8),
              Text(
                "Target Budgets for Next Month",
                style: AppTheme.getSubHeadingStyle(colors, size: 15),
              ),
            ],
          ),
          const Divider(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: budgets.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.paperLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: AppTheme.getBodyStyle(colors, size: 11.5, soft: true),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      format.format(entry.value),
                      style: AppTheme.getMonoStyle(colors, size: 13, weight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

