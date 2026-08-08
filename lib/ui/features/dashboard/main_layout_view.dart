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
  ];

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
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
                  child: Column(
                    children: [
                      Text(
                        _currentTab == AppTab.expenses
                            ? "Daily Record"
                            : (_currentTab == AppTab.income
                                ? "Cash Flow"
                                : (_currentTab == AppTab.ledgers
                                    ? "Custom Books"
                                    : (_currentTab == AppTab.recurring
                                        ? "Reminders"
                                        : "Analysis"))),
                        style: AppTheme.getMonoStyle(colors, size: 11, weight: FontWeight.w600).copyWith(
                          color: colors.brassDark,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Personal Ledger",
                        style: AppTheme.getHeadingStyle(colors).copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          unselectedItemColor: colors.inkSoft.withOpacity(0.6),
          selectedLabelStyle: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 11),
          unselectedLabelStyle: AppTheme.getBodyStyle(colors, weight: FontWeight.w500, size: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined),
              activeIcon: Icon(Icons.trending_up),
              label: 'Income',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Ledgers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_outlined),
              activeIcon: Icon(Icons.alarm),
              label: 'Recurring',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Advisor',
            ),
          ],
        ),
      ),
    );
  }
}
