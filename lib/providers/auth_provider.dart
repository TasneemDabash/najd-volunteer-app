import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final AccountService _accountService = AccountService();

  User? _user;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isProfileLoading = false;
  String? _error;

  User? get user => _user;
  UserProfile? get profile => _profile;
  UserRole get role => _profile?.role ?? UserRole.volunteer;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _isProfileLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
    _authService.authStateChanges.listen(_onAuthStateChange);
  }

  void _setUser(User? user) {
    _user = user;
    if (user == null) {
      _profile = null;
    }
  }

  Future<void> _init() async {
    _setUser(await _authService.getSession());
    if (_user != null) {
      await _loadProfile();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    _isProfileLoading = true;
    notifyListeners();
    try {
      _profile = await _accountService.getOrCreateProfile(
        email: _user?.email,
      );
    } catch (_) {
      // keep existing profile/null on error
    }
    _isProfileLoading = false;
    notifyListeners();
  }

  /// Reload [profiles] from Supabase (e.g. after an admin changes your role in the dashboard).
  Future<void> refreshProfile() async {
    if (_user == null) return;
    _isProfileLoading = true;
    notifyListeners();
    try {
      final latest = await _accountService.getProfile();
      _profile = latest ?? _profile;
      if (_profile == null) {
        _profile = await _accountService.getOrCreateProfile(
          email: _user?.email,
        );
      }
    } catch (_) {
      // keep cached profile
    }
    _isProfileLoading = false;
    notifyListeners();
  }

  void _onAuthStateChange(AuthState data) {
    _setUser(data.session?.user);
    if (_user != null) {
      _loadProfile();
    } else {
      notifyListeners();
    }
  }

  String _formatError(dynamic e) {
    final errorStr = e.toString().toLowerCase();

    // Connection errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection failed') ||
        errorStr.contains('operation not permitted') ||
        errorStr.contains('network is unreachable')) {
      return 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';
    }

    // Timeout errors
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
    }

    // Invalid credentials
    if (errorStr.contains('invalid login') ||
        errorStr.contains('invalid credentials') ||
        errorStr.contains('wrong password')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }

    // User not found
    if (errorStr.contains('user not found') ||
        errorStr.contains('no user found')) {
      return 'لم يتم العثور على حساب بهذا البريد الإلكتروني.';
    }

    // Email already exists
    if (errorStr.contains('already registered') ||
        errorStr.contains('already exists') ||
        errorStr.contains('duplicate')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً.';
    }

    // Too many requests
    if (errorStr.contains('too many requests') ||
        errorStr.contains('rate limit')) {
      return 'محاولات كثيرة جداً. انتظر قليلاً ثم حاول مرة أخرى.';
    }

    // Generic server error
    if (errorStr.contains('500') || errorStr.contains('server error')) {
      return 'حدث خطأ في الخادم. حاول مرة أخرى لاحقاً.';
    }

    // Default fallback
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  String _formatAuthError(AuthException e) {
    final message = e.message.toLowerCase();

    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (message.contains('email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً.';
    }
    if (message.contains('user not found')) {
      return 'لم يتم العثور على حساب بهذا البريد الإلكتروني.';
    }
    if (message.contains('already registered')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً.';
    }
    if (message.contains('weak password')) {
      return 'كلمة المرور ضعيفة جداً. استخدم كلمة مرور أقوى.';
    }
    if (message.contains('invalid email')) {
      return 'البريد الإلكتروني غير صالح.';
    }

    return e.message;
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      _setUser(_authService.currentUser);
      await _loadProfile();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(
    String email,
    String password, {
    String? fullName,
    String? phone,
    String? city,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signUp(email: email, password: password);
      _setUser(_authService.currentUser);
      // Create profile with provided info
      _profile = await _accountService.getOrCreateProfile(
        email: email,
        fullName: fullName,
        phone: phone,
        city: city,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset password - sends reset email via Supabase
  Future<bool> resetPassword(String email) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _formatAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _setUser(null);
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
