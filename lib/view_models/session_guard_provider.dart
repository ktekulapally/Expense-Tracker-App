import 'dart:async';
import 'package:flutter/material.dart';
import '../data/services/supabase_service.dart';

class SessionGuardProvider extends ChangeNotifier {
  final SupabaseService _service;
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;

  SessionGuardProvider(this._service) {
    _startTimer();
    _service.authStateChanges.listen((state) {
      if (state.session != null) {
        resetActivity();
      } else {
        _stopTimer();
      }
    });
  }

  void resetActivity() {
    _lastActivity = DateTime.now();
    if (_timer == null && _service.currentUser != null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_service.currentUser == null) {
        _stopTimer();
        return;
      }
      final difference = DateTime.now().difference(_lastActivity);
      if (difference.inMinutes >= 60) {
        _performLogout();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _performLogout() async {
    _stopTimer();
    try {
      await _service.signOut();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
