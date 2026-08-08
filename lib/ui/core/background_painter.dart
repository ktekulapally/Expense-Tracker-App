import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class BackgroundPainter extends CustomPainter {
  final AppTab tab;
  final AppThemeColors colors;

  BackgroundPainter({required this.tab, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.paperLine
      ..strokeWidth = 1.0;

    switch (tab) {
      case AppTab.expenses:
        _paintExpenses(canvas, size, paint);
        break;
      case AppTab.income:
        _paintIncome(canvas, size, paint);
        break;
      case AppTab.recurring:
        _paintRecurring(canvas, size, paint);
        break;
      case AppTab.ledgers:
        _paintLedgers(canvas, size, paint);
        break;
      case AppTab.insights:
        _paintInsights(canvas, size, paint);
        break;
    }
  }

  // Fine horizontal ledger rules
  void _paintExpenses(Canvas canvas, Size size, Paint paint) {
    const double spacing = 32.0;
    const double startY = 120.0;
    for (double y = startY; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // Soft dot-grid
  void _paintIncome(Canvas canvas, Size size, Paint paint) {
    const double spacing = 18.0;
    paint.style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  // Gentle diagonal hatch
  void _paintRecurring(Canvas canvas, Size size, Paint paint) {
    const double spacing = 14.0;
    paint.strokeWidth = 0.8;
    
    // Draw lines along diagonal paths
    for (double offset = -size.height; offset < size.width; offset += spacing) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  // Fine grid (Ledger spreadsheet check)
  void _paintLedgers(Canvas canvas, Size size, Paint paint) {
    const double spacing = 22.0;
    paint.strokeWidth = 0.7;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // Soft dashed rows
  void _paintInsights(Canvas canvas, Size size, Paint paint) {
    const double spacing = 12.0;
    const double dashLength = 4.0;
    const double spaceLength = 4.0;
    paint.strokeWidth = 0.8;

    for (double y = 0; y < size.height; y += spacing) {
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(math.min(startX + dashLength, size.width), y),
          paint,
        );
        startX += dashLength + spaceLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return oldDelegate.tab != tab || oldDelegate.colors != colors;
  }
}

class ThemeBackground extends StatelessWidget {
  final AppTab tab;
  final Widget child;

  const ThemeBackground({
    super.key,
    required this.tab,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.getColors(tab);
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: colors.paper),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.05,
            child: Image.asset(
              'assets/images/logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: BackgroundPainter(tab: tab, colors: colors),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
