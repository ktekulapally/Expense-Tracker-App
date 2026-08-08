import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/services/supabase_service.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/main_ledger_view_model.dart';
import 'view_models/ledger_view_model.dart';
import 'view_models/recurring_view_model.dart';
import 'view_models/session_guard_provider.dart';
import 'ui/features/auth/auth_view.dart';
import 'ui/features/dashboard/main_layout_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with the web app project credentials
  await Supabase.initialize(
    url: SupabaseService.supabaseUrl,
    anonKey: SupabaseService.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<SupabaseService>(
          create: (_) => SupabaseService(),
        ),
        ChangeNotifierProxyProvider<SupabaseService, AuthViewModel>(
          create: (context) => AuthViewModel(context.read<SupabaseService>()),
          update: (context, service, previous) => previous ?? AuthViewModel(service),
        ),
        ChangeNotifierProxyProvider<SupabaseService, MainLedgerViewModel>(
          create: (context) => MainLedgerViewModel(context.read<SupabaseService>()),
          update: (context, service, previous) => previous ?? MainLedgerViewModel(service),
        ),
        ChangeNotifierProxyProvider<SupabaseService, LedgerViewModel>(
          create: (context) => LedgerViewModel(context.read<SupabaseService>()),
          update: (context, service, previous) => previous ?? LedgerViewModel(service),
        ),
        ChangeNotifierProxyProvider<SupabaseService, RecurringViewModel>(
          create: (context) => RecurringViewModel(context.read<SupabaseService>()),
          update: (context, service, previous) => previous ?? RecurringViewModel(service),
        ),
        ChangeNotifierProxyProvider<SupabaseService, SessionGuardProvider>(
          create: (context) => SessionGuardProvider(context.read<SupabaseService>()),
          update: (context, service, previous) => previous ?? SessionGuardProvider(service),
        ),
      ],
      child: const PersonalLedgerApp(),
    ),
  );
}

class PersonalLedgerApp extends StatelessWidget {
  const PersonalLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return MaterialApp(
      title: 'Personal Ledger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: authViewModel.isAuthenticated ? const MainLayoutView() : const AuthView(),
    );
  }
}
