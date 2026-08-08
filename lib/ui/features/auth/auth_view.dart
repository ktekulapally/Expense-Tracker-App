import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../view_models/auth_view_model.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/background_painter.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final colors = AppTheme.expensesColors; // auth uses the default expenses background colors

    return Scaffold(
      body: ThemeBackground(
        tab: AppTab.expenses,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.ink.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: colors.brass,
                        width: 2.5,
                      ),
                    ),
                    child: const ClipOval(
                      child: Image(
                        image: AssetImage('assets/images/logo.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Masthead Header style
                  Text(
                    "Daily Record",
                    style: AppTheme.getMonoStyle(colors, size: 12, weight: FontWeight.w600).copyWith(
                      color: colors.brassDark,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Personal Ledger",
                    style: AppTheme.getHeadingStyle(colors),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 64,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.brass,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Auth Card mimicking .auth-card from styles.css
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: AppTheme.cardDecoration(colors),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          authViewModel.isSignupMode ? 'Create your ledger' : 'Welcome back',
                          style: AppTheme.getSubHeadingStyle(colors, size: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authViewModel.isSignupMode
                              ? 'Set up your account to start tracking.'
                              : 'Sign in to your ledger.',
                          style: AppTheme.getBodyStyle(colors, soft: true, size: 13),
                        ),
                        const SizedBox(height: 20),

                        // Error Messages
                        if (authViewModel.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.red.withOpacity(0.2)),
                            ),
                            child: Text(
                              authViewModel.errorMessage!,
                              style: AppTheme.getBodyStyle(colors, size: 13).copyWith(color: colors.red),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Info Messages
                        if (authViewModel.infoMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.green.withOpacity(0.2)),
                            ),
                            child: Text(
                              authViewModel.infoMessage!,
                              style: AppTheme.getBodyStyle(colors, size: 13).copyWith(color: colors.green),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        AppTextField(
                          label: "Email address",
                          placeholder: "your@email.com",
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          colors: colors,
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          label: "Password",
                          placeholder: "••••••••",
                          controller: _passwordController,
                          obscureText: true,
                          colors: colors,
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          text: authViewModel.isSignupMode ? "Create account" : "Sign in",
                          isLoading: authViewModel.isLoading,
                          colors: colors,
                          onPressed: () {
                            authViewModel.submitAuth(
                              _emailController.text,
                              _passwordController.text,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mode toggling
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              authViewModel.isSignupMode ? 'Already have an account? ' : 'New here? ',
                              style: AppTheme.getBodyStyle(colors, size: 13, soft: true),
                            ),
                            GestureDetector(
                              onTap: authViewModel.toggleAuthMode,
                              child: Text(
                                authViewModel.isSignupMode ? 'Sign in' : 'Create an account',
                                style: AppTheme.getBodyStyle(colors, size: 13, weight: FontWeight.w600).copyWith(
                                  color: colors.brassDark,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Forgot password
                        if (!authViewModel.isSignupMode) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                authViewModel.triggerPasswordReset(_emailController.text);
                              },
                              child: Text(
                                "Forgot password?",
                                style: AppTheme.getBodyStyle(colors, size: 12).copyWith(
                                  color: colors.inkSoft,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    "Your data is stored in your own Supabase project.",
                    style: AppTheme.getBodyStyle(colors, soft: true, size: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
