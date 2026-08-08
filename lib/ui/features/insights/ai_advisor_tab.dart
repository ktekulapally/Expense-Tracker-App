import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/services/supabase_service.dart';
import '../../../view_models/auth_view_model.dart';
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
  String? _adviceMarkdown;
  Map<String, double>? _categoryData;
  String? _errorMessage;

  final List<Color> _chartColors = [
    const Color(0xFF1C2B3A),
    const Color(0xFF3F7A5C),
    const Color(0xFFB9863F),
    const Color(0xFFA6432D),
    const Color(0xFF7A8C99),
    const Color(0xFFC9A86A),
    const Color(0xFF5C7A6A),
    const Color(0xFF8F6529),
  ];

  Future<void> _runAnalysis() async {
    setState(() {
      _isLoading = true;
      _adviceMarkdown = null;
      _categoryData = null;
      _errorMessage = null;
    });

    try {
      final service = context.read<SupabaseService>();
      final result = await service.analyzeSpending(period: _selectedPeriod);
      
      setState(() {
        _adviceMarkdown = result['advice'] as String?;
        if (result['byCategory'] != null) {
          final Map<String, dynamic> rawMap = result['byCategory'] as Map<String, dynamic>;
          _categoryData = rawMap.map((key, value) => MapEntry(key, double.parse(value.toString())));
        }
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Control box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(colors),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Where is your money going?",
                  style: AppTheme.getSubHeadingStyle(colors, size: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  "Sends a summary of your category totals to an open-weight LLM for a plain-language read and a few practical suggestions.",
                  style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                ),
                const SizedBox(height: 16),

                // Range toggles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['1m', '3m', '6m'].map((p) {
                    final isSel = _selectedPeriod == p;
                    return OutlinedButton(
                      onPressed: () => setState(() => _selectedPeriod = p),
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
                  text: "Analyze spending",
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

          // Loading / Chart / Advice Output
          if (_isLoading)
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
          else ...[
            // Breakdown chart
            if (_categoryData != null && _categoryData!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(colors),
                child: Column(
                  children: [
                    Text(
                      "Breakdown by Category",
                      style: AppTheme.getSubHeadingStyle(colors, size: 15),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildChartSections(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Legend
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: _buildChartLegend(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Advice Text
            if (_adviceMarkdown != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(colors),
                child: MarkdownBody(
                  data: _adviceMarkdown!,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTheme.getBodyStyle(colors, size: 14),
                    h1: AppTheme.getSubHeadingStyle(colors, size: 20),
                    h2: AppTheme.getSubHeadingStyle(colors, size: 17),
                    listBullet: AppTheme.getBodyStyle(colors, size: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "This is general, automatically generated information based on your own logged data — not financial advice.",
                style: AppTheme.getBodyStyle(colors, soft: true, size: 11),
                textAlign: TextAlign.center,
              ),
            ] else if (!_isLoading && _errorMessage == null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration(colors),
                child: Center(
                  child: Text(
                    "Pick a time range and click \"Analyze spending\" to get started.",
                    style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections() {
    final Map<String, double> data = _categoryData!;
    final List<PieChartSectionData> sections = [];
    int i = 0;

    data.forEach((key, val) {
      final color = _chartColors[i % _chartColors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: val,
          title: '₹${val.toStringAsFixed(0)}',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      i++;
    });

    return sections;
  }

  List<Widget> _buildChartLegend() {
    final Map<String, double> data = _categoryData!;
    final List<Widget> legend = [];
    int i = 0;

    data.forEach((key, val) {
      final color = _chartColors[i % _chartColors.length];
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
              "$key: ₹${val.toStringAsFixed(2)}",
              style: AppTheme.getBodyStyle(AppTheme.insightsColors, size: 11, soft: true),
            ),
          ],
        ),
      );
      i++;
    });

    return legend;
  }
}
