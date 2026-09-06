import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'gemini_receipt_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// FinancialAdvisoryReport
///
/// Structured advisory model containing executive health score, 50/30/20
/// allocation, key insights, cost-cutting action items, and full markdown report.
/// ─────────────────────────────────────────────────────────────────────────
class FinancialAdvisoryReport {
  final String executiveSummary;
  final String healthScore; // "Excellent" (Green), "Good" (Teal), "Fair" (Amber), "Action Needed" (Red)
  final double savingsRatePercent;
  final double needsPercent; // 50% target
  final double wantsPercent; // 30% target
  final double savingsPercent; // 20% target
  final List<String> keyObservations;
  final List<String> actionItems;
  final Map<String, double> recommendedCategoryBudgets;
  final String fullMarkdown;

  const FinancialAdvisoryReport({
    required this.executiveSummary,
    required this.healthScore,
    required this.savingsRatePercent,
    required this.needsPercent,
    required this.wantsPercent,
    required this.savingsPercent,
    required this.keyObservations,
    required this.actionItems,
    required this.recommendedCategoryBudgets,
    required this.fullMarkdown,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// GeminiAdvisorService
///
/// Leverages Google Gemini Flash models to provide Certified Financial Planner (CFP)
/// grade spending analysis, cash-flow diagnostic, and tailored cost-cutting levers.
/// ─────────────────────────────────────────────────────────────────────────
class GeminiAdvisorService {
  static const List<String> _models = [
    'gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Categorizes categories into Needs (50) vs Wants (30) for 50/30/20 rule
  static bool isNeedCategory(String category) {
    final cat = category.toLowerCase().trim();
    return cat.contains('grocer') ||
        cat.contains('rent') ||
        cat.contains('electricity') ||
        cat.contains('power') ||
        cat.contains('water') ||
        cat.contains('utilit') ||
        cat.contains('health') ||
        cat.contains('medicine') ||
        cat.contains('fuel') ||
        cat.contains('petrol') ||
        cat.contains('mobile') ||
        cat.contains('wifi') ||
        cat.contains('broadband');
  }

  /// Generates a complete financial analysis report using Gemini Flash or local fallback.
  Future<FinancialAdvisoryReport> generateAdvisory({
    required String periodLabel,
    required double totalIncome,
    required double totalExpenses,
    required Map<String, double> categoryTotals,
    required List<Expense> periodExpenses,
    required List<Income> periodIncome,
    required List<RecurringExpense> recurringTemplates,
  }) async {
    final netSavings = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100.0 : (totalExpenses > 0 ? -100.0 : 0.0);

    // Compute Needs vs Wants distribution
    double needsTotal = 0.0;
    double wantsTotal = 0.0;

    categoryTotals.forEach((cat, amount) {
      if (isNeedCategory(cat)) {
        needsTotal += amount;
      } else {
        wantsTotal += amount;
      }
    });

    final double effectiveBase = totalIncome > 0 ? totalIncome : totalExpenses;
    final double needsPct = effectiveBase > 0 ? (needsTotal / effectiveBase) * 100.0 : 0.0;
    final double wantsPct = effectiveBase > 0 ? (wantsTotal / effectiveBase) * 100.0 : 0.0;
    final double savingsPct = totalIncome > 0 ? (netSavings / totalIncome) * 100.0 : 0.0;

    final apiKey = GeminiReceiptService.apiKey.trim();

    if (apiKey.isNotEmpty) {
      try {
        final geminiReport = await _callGeminiApi(
          apiKey: apiKey,
          periodLabel: periodLabel,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          netSavings: netSavings,
          savingsRate: savingsRate,
          needsTotal: needsTotal,
          wantsTotal: wantsTotal,
          categoryTotals: categoryTotals,
          recurringTemplates: recurringTemplates,
          periodExpenses: periodExpenses,
        );

        if (geminiReport != null) {
          return geminiReport;
        }
      } catch (e) {
        debugPrint('Gemini Advisor API call failed, falling back to heuristic report: $e');
      }
    }

    // Heuristic Local Fallback Report (Instant & Offline)
    return _generateHeuristicReport(
      periodLabel: periodLabel,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netSavings: netSavings,
      savingsRate: savingsRate,
      needsPct: needsPct,
      wantsPct: wantsPct,
      savingsPct: savingsPct,
      categoryTotals: categoryTotals,
    );
  }

  Future<FinancialAdvisoryReport?> _callGeminiApi({
    required String apiKey,
    required String periodLabel,
    required double totalIncome,
    required double totalExpenses,
    required double netSavings,
    required double savingsRate,
    required double needsTotal,
    required double wantsTotal,
    required Map<String, double> categoryTotals,
    required List<RecurringExpense> recurringTemplates,
    required List<Expense> periodExpenses,
  }) async {
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoryLines = sortedCategories
        .map((e) => '- ${e.key}: ₹${e.value.toStringAsFixed(2)} (${totalExpenses > 0 ? ((e.value / totalExpenses) * 100).toStringAsFixed(1) : "0"}%)')
        .join('\n');

    final recurringLines = recurringTemplates
        .where((r) => r.active)
        .map((r) => '- ${r.name} (${r.category}): ₹${r.amount.toStringAsFixed(2)} due day ${r.paymentDay}')
        .join('\n');

    final prompt = '''
You are an expert Certified Financial Planner (CFP) and Wealth Advisor providing a high-impact, professional financial health audit.
Analyze the user's spending ledger over the period "$periodLabel" (Currency: Indian Rupee ₹ INR).

FINANCIAL SUMMARY:
- Total Inflows (Income): ₹${totalIncome.toStringAsFixed(2)}
- Total Outflows (Expenses): ₹${totalExpenses.toStringAsFixed(2)}
- Net Cash Flow: ₹${netSavings.toStringAsFixed(2)}
- Current Savings Rate: ${savingsRate.toStringAsFixed(1)}%
- Essential Needs Spend: ₹${needsTotal.toStringAsFixed(2)}
- Discretionary Wants Spend: ₹${wantsTotal.toStringAsFixed(2)}

CATEGORY BREAKDOWN (Descending):
$categoryLines

FIXED RECURRING COMMITMENTS:
${recurringLines.isNotEmpty ? recurringLines : "None registered"}

INSTRUCTIONS:
Provide a concise, highly analytical, and structured financial advisory report with:
1. Executive Health Score: Pick exactly one from ["Excellent", "Good", "Fair", "Action Needed"].
2. Executive Summary (2-3 sentences explaining their financial position).
3. 50/30/20 Budget Assessment: Compare their current allocation (Needs/Wants/Savings) against the recommended 50% Needs, 30% Wants, 20% Savings.
4. Key Observations (2-3 distinct bullet points identifying specific spending patterns or cost leaks).
5. High-Impact Action Items (3 practical steps with estimated monthly rupee savings to improve cash flow).
6. Recommended Next Month Budget allocation for top 4 categories.

Return a valid JSON object with the following schema:
{
  "healthScore": "Good",
  "executiveSummary": "Summary text here...",
  "needsPercent": 52.0,
  "wantsPercent": 28.0,
  "savingsPercent": 20.0,
  "keyObservations": [
    "Observation 1...",
    "Observation 2..."
  ],
  "actionItems": [
    "Action 1 (Save ₹X)...",
    "Action 2 (Save ₹Y)...",
    "Action 3..."
  ],
  "recommendedBudgets": {
    "Groceries": 12000,
    "Food": 5000,
    "Fuel": 3000
  },
  "markdownReport": "### 📊 Executive Financial Diagnosis\\n\\n..."
}
''';

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json",
        "temperature": 0.2,
      }
    };

    for (final model in _models) {
      final url = Uri.parse('$_baseUrl/$model:generateContent?key=$apiKey');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final jsonText = parts[0]['text'] as String?;
              if (jsonText != null) {
                return _parseJsonResponse(jsonText, savingsRate);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini Advisor ($model) attempt error: $e');
      }
    }
    return null;
  }

  FinancialAdvisoryReport _parseJsonResponse(String jsonString, double actualSavingsRate) {
    final cleanJson = jsonString
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .trim();

    final map = jsonDecode(cleanJson) as Map<String, dynamic>;

    final healthScore = map['healthScore'] as String? ?? 'Good';
    final execSummary = map['executiveSummary'] as String? ?? 'Financial analysis completed.';
    final needsPct = (map['needsPercent'] as num?)?.toDouble() ?? 50.0;
    final wantsPct = (map['wantsPercent'] as num?)?.toDouble() ?? 30.0;
    final savingsPct = (map['savingsPercent'] as num?)?.toDouble() ?? actualSavingsRate;

    final observations = (map['keyObservations'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final actionItems = (map['actionItems'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final rawBudgets = map['recommendedBudgets'] as Map<String, dynamic>? ?? {};
    final recBudgets = rawBudgets.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final markdownReport = map['markdownReport'] as String? ?? '';

    return FinancialAdvisoryReport(
      executiveSummary: execSummary,
      healthScore: healthScore,
      savingsRatePercent: actualSavingsRate,
      needsPercent: needsPct,
      wantsPercent: wantsPct,
      savingsPercent: savingsPct,
      keyObservations: observations,
      actionItems: actionItems,
      recommendedCategoryBudgets: recBudgets,
      fullMarkdown: markdownReport.isNotEmpty ? markdownReport : _buildMarkdown(execSummary, observations, actionItems),
    );
  }

  String _buildMarkdown(String summary, List<String> observations, List<String> actions) {
    final buffer = StringBuffer();
    buffer.writeln('### 📊 Executive Financial Diagnosis\n');
    buffer.writeln('$summary\n');

    if (observations.isNotEmpty) {
      buffer.writeln('#### 🔍 Key Spending Observations');
      for (final obs in observations) {
        buffer.writeln('- $obs');
      }
      buffer.writeln();
    }

    if (actions.isNotEmpty) {
      buffer.writeln('#### 💡 Recommended Action Items');
      for (final act in actions) {
        buffer.writeln('- $act');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  FinancialAdvisoryReport _generateHeuristicReport({
    required String periodLabel,
    required double totalIncome,
    required double totalExpenses,
    required double netSavings,
    required double savingsRate,
    required double needsPct,
    required double wantsPct,
    required double savingsPct,
    required Map<String, double> categoryTotals,
  }) {
    String healthScore;
    if (savingsRate >= 30) {
      healthScore = "Excellent";
    } else if (savingsRate >= 15) {
      healthScore = "Good";
    } else if (savingsRate >= 0) {
      healthScore = "Fair";
    } else {
      healthScore = "Action Needed";
    }

    final sorted = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = sorted.isNotEmpty ? sorted.first.key : 'None';
    final topCategoryAmount = sorted.isNotEmpty ? sorted.first.value : 0.0;
    final topCategoryShare = totalExpenses > 0 ? (topCategoryAmount / totalExpenses) * 100.0 : 0.0;

    final summary = totalIncome > 0
        ? "During $periodLabel, you earned ₹${totalIncome.toStringAsFixed(2)} and spent ₹${totalExpenses.toStringAsFixed(2)}, maintaining a **${savingsRate.toStringAsFixed(1)}% net savings rate**."
        : "During $periodLabel, total expenses reached ₹${totalExpenses.toStringAsFixed(2)}. Logging regular income will unlock full cash-flow optimization.";

    final observations = <String>[
      "Top spending driver is **$topCategory** at ₹${topCategoryAmount.toStringAsFixed(2)} (${topCategoryShare.toStringAsFixed(0)}% of all expenses).",
      needsPct > 65
          ? "Essential living costs (Needs) account for **${needsPct.toStringAsFixed(0)}%** of your budget, higher than the standard 50% target."
          : "Essential needs spending is well-balanced at **${needsPct.toStringAsFixed(0)}%** of cash flow.",
      wantsPct > 35
          ? "Discretionary spending (Wants like dining & shopping) stands at **${wantsPct.toStringAsFixed(0)}%**, presenting immediate room for optimization."
          : "Discretionary spending is well controlled within healthy limits (${wantsPct.toStringAsFixed(0)}%).",
    ];

    final actionItems = <String>[
      "Target a 10% reduction in **$topCategory** next month to free up approximately ₹${(topCategoryAmount * 0.1).toStringAsFixed(0)} in monthly cash flow.",
      "Track recurring subscriptions and bill due dates to avoid late payment surcharges.",
      savingsRate < 20
          ? "Aim to boost your savings rate toward the standard **20% benchmark** by capping discretionary impulse purchases."
          : "Consider allocating surplus monthly savings into automated emergency reserves or high-yield investments.",
    ];

    final recommendedBudgets = <String, double>{};
    for (int i = 0; i < sorted.length && i < 4; i++) {
      final entry = sorted[i];
      recommendedBudgets[entry.key] = (entry.value * 0.95).roundToDouble();
    }

    return FinancialAdvisoryReport(
      executiveSummary: summary,
      healthScore: healthScore,
      savingsRatePercent: savingsRate,
      needsPercent: needsPct,
      wantsPercent: wantsPct,
      savingsPercent: savingsPct,
      keyObservations: observations,
      actionItems: actionItems,
      recommendedCategoryBudgets: recommendedBudgets,
      fullMarkdown: _buildMarkdown(summary, observations, actionItems),
    );
  }
}
