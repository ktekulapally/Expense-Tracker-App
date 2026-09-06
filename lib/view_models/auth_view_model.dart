import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/services/supabase_service.dart';

class AuthViewModel extends ChangeNotifier {
  final SupabaseService _service;
  
  AuthViewModel(this._service) {
    _service.authStateChanges.listen((data) {
      notifyListeners();
    });
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _infoMessage;
  String? get infoMessage => _infoMessage;

  bool _isSignupMode = false;
  bool get isSignupMode => _isSignupMode;

  User? get currentUser => _service.currentUser;
  bool get isAuthenticated => currentUser != null;

  void toggleAuthMode() {
    _isSignupMode = !_isSignupMode;
    clearMessages();
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  Future<void> submitAuth(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = "Enter both email and password.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      if (_isSignupMode) {
        final res = await _service.signUp(email.trim(), password);
        if (res.user != null) {
          _infoMessage = "Account created. Check your email if confirmation is required, then sign in.";
        }
      } else {
        await _service.signIn(email.trim(), password);
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> triggerPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      _errorMessage = 'Enter your email above first, then click "Forgot password?".';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _service.resetPassword(email.trim());
      _infoMessage = 'Password reset link sent to $email. Check your inbox (and spam folder).';
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
