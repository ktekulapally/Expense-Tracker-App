import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppTab { expenses, income, ledgers, recurring, insights }

class AppThemeColors {
  final Color paper;
  final Color paperLine;
  final Color ink;
  final Color inkSoft;
  final Color brass;
  final Color brassDark;
  final Color red;
  final Color green;
  final Color card;

  const AppThemeColors({
    required this.paper,
    required this.paperLine,
    required this.ink,
    required this.inkSoft,
    required this.brass,
    required this.brassDark,
    required this.red,
    required this.green,
    required this.card,
  });
}

class AppTheme {
  static const AppThemeColors expensesColors = AppThemeColors(
    paper: Color(0xFFE7ECF1),
    paperLine: Color(0xFFCDD8E2),
    ink: Color(0xFF1C2B3A),
    inkSoft: Color(0xFF4A5A6A),
    brass: Color(0xFFB9863F),
    brassDark: Color(0xFF8F6529),
    red: Color(0xFFA6432D),
    green: Color(0xFF3F7A5C),
    card: Color(0xFFF8F9FB),
  );

  static const AppThemeColors incomeColors = AppThemeColors(
    paper: Color(0xFFE3F0E6),
    paperLine: Color(0xFFC3DBC8),
    ink: Color(0xFF1C2B3A),
    inkSoft: Color(0xFF4A5A6A),
    brass: Color(0xFFB9863F),
    brassDark: Color(0xFF8F6529),
    red: Color(0xFFA6432D),
    green: Color(0xFF3F7A5C),
    card: Color(0xFFF4FAF5),
  );

  static const AppThemeColors recurringColors = AppThemeColors(
    paper: Color(0xFFF6ECD8),
    paperLine: Color(0xFFE5D3A8),
    ink: Color(0xFF1C2B3A),
    inkSoft: Color(0xFF4A5A6A),
    brass: Color(0xFFB9863F),
    brassDark: Color(0xFF8F6529),
    red: Color(0xFFA6432D),
    green: Color(0xFF3F7A5C),
    card: Color(0xFFFCF7EA),
  );

  static const AppThemeColors ledgersColors = AppThemeColors(
    paper: Color(0xFFEFE9F5),
    paperLine: Color(0xFFD9CCE8),
    ink: Color(0xFF1C2B3A),
    inkSoft: Color(0xFF4A5A6A),
    brass: Color(0xFFB9863F),
    brassDark: Color(0xFF8F6529),
    red: Color(0xFFA6432D),
    green: Color(0xFF3F7A5C),
    card: Color(0xFFFAF7FC),
  );

  static const AppThemeColors insightsColors = AppThemeColors(
    paper: Color(0xFFE4F0EF),
    paperLine: Color(0xFFC7DDD9),
    ink: Color(0xFF1C2B3A),
    inkSoft: Color(0xFF4A5A6A),
    brass: Color(0xFFB9863F),
    brassDark: Color(0xFF8F6529),
    red: Color(0xFFA6432D),
    green: Color(0xFF3F7A5C),
    card: Color(0xFFF5FAFA),
  );

  static AppThemeColors getColors(AppTab tab) {
    switch (tab) {
      case AppTab.expenses:
        return expensesColors;
      case AppTab.income:
        return incomeColors;
      case AppTab.recurring:
        return recurringColors;
      case AppTab.ledgers:
        return ledgersColors;
      case AppTab.insights:
        return insightsColors;
    }
  }

  // Typography helpers
  static TextStyle getEyebrowStyle(AppThemeColors colors) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
      color: colors.brassDark,
    );
  }

  static TextStyle getHeadingStyle(AppThemeColors colors) {
    return GoogleFonts.fraunces(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      color: colors.ink,
      letterSpacing: -0.5,
    );
  }

  static TextStyle getSubHeadingStyle(AppThemeColors colors, {double size = 20}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: colors.ink,
    );
  }

  static TextStyle getBodyStyle(AppThemeColors colors, {bool soft = false, double size = 14, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: soft ? colors.inkSoft : colors.ink,
    );
  }

  static TextStyle getMonoStyle(AppThemeColors colors, {double size = 14, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: colors.ink,
    );
  }

  static BoxDecoration cardDecoration(AppThemeColors colors) {
    return BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.paperLine),
      boxShadow: [
        BoxShadow(
          color: colors.ink.withOpacity(0.04),
          offset: const Offset(0, 1),
          blurRadius: 0,
        ),
      ],
    );
  }
}
