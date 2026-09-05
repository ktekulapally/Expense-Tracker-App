import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../view_models/auth_view_model.dart';
import '../../../view_models/session_guard_provider.dart';
import '../../core/theme.dart';
import '../../core/background_painter.dart';
import '../expenses/expenses_tab.dart';
import '../income/income_tab.dart';
import '../ledgers/ledgers_tab.dart';
import '../recurring/recurring_tab.dart';
import '../insights/ai_advisor_tab.dart';
import '../charts/bento_expense_chart_view.dart';

class MainLayoutView extends StatefulWidget {
  const MainLayoutView({super.key});

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  AppTab _currentTab = AppTab.expenses;

  final List<Widget> _tabs = [
    const ExpensesTab(),
    const IncomeTab(),
    const LedgersTab(),
    const RecurringTab(),
    const AiAdvisorTab(),
    const BentoExpenseChartView(),
  ];

  String _getSubtitle() {
    switch (_currentTab) {
      case AppTab.expenses:
        return "Daily Record";
      case AppTab.income:
        return "Cash Flow";
      case AppTab.ledgers:
        return "Custom Books";
      case AppTab.recurring:
        return "Reminders";
      case AppTab.insights:
        return "AI Advisor";
      case AppTab.charts:
        return "Visual Summary";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final sessionGuard = context.watch<SessionGuardProvider>();

    final colors = AppTheme.getColors(_currentTab);

    // Enforce interactive reset
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        sessionGuard.resetActivity();
      },
      onPointerSignal: (_) {
        sessionGuard.resetActivity();
      },
      child: Scaffold(
        body: ThemeBackground(
          tab: _currentTab,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Global Masthead Header
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Column(
                    children: [
                      Text(
                        _getSubtitle(),
                        style: AppTheme.getMonoStyle(colors, size: 11, weight: FontWeight.w600).copyWith(
                          color: colors.brassDark,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Personal Ledger",
                        style: AppTheme.getHeadingStyle(colors).copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 48,
                        height: 3,
                        decoration: BoxDecoration(
                          color: colors.brass,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Signed-in User Info & Sign-out (Toolbar style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Signed in as: ${authViewModel.currentUser?.email ?? ''}",
                          style: AppTheme.getBodyStyle(colors, soft: true, size: 12, weight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => authViewModel.signOut(),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.inkSoft,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Sign out",
                          style: AppTheme.getBodyStyle(colors, soft: true, size: 12, weight: FontWeight.w600).copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Active Tab Content
                Expanded(
                  child: IndexedStack(
                    index: _currentTab.index,
                    children: _tabs,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab.index,
          onTap: (index) {
            setState(() {
              _currentTab = AppTab.values[index];
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: colors.card,
          selectedItemColor: colors.ink,
          unselectedItemColor: colors.inkSoft.withValues(alpha: 0.6),
          selectedLabelStyle: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 10),
          unselectedLabelStyle: AppTheme.getBodyStyle(colors, weight: FontWeight.w500, size: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
              activeIcon: Icon(Icons.account_balance_wallet, size: 20),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined, size: 20),
              activeIcon: Icon(Icons.trending_up, size: 20),
              label: 'Income',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined, size: 20),
              activeIcon: Icon(Icons.book, size: 20),
              label: 'Ledgers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_outlined, size: 20),
              activeIcon: Icon(Icons.alarm, size: 20),
              label: 'Recurring',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined, size: 20),
              activeIcon: Icon(Icons.insights, size: 20),
              label: 'Advisor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined, size: 20),
              activeIcon: Icon(Icons.grid_view_rounded, size: 20),
              label: 'Charts',
            ),
          ],
        ),
      ),
    );
  }
}
