import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/secure_session.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository repository;
  final SecureSession secureSession;

  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  bool _isLoading = true;
  String? _errorMessage;

  AuthProvider({required this.repository, required this.secureSession}) {
    _hydrate();
  }

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  bool get isAuthenticated => _token?.isNotEmpty == true;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _hydrate() async {
    final preferences = await SharedPreferences.getInstance();
    _token = await secureSession.readToken();
    _userId = await secureSession.readUserId();
    _userName = preferences.getString('userName');
    _userEmail = preferences.getString('userEmail');
    _userPhone = preferences.getString('userPhone');
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _startRequest();
    try {
      final response = await repository.login(email, password);
      final token = response['token']?.toString();
      final userId = response['id']?.toString();
      if (response['emailVerified'] != true || token == null || userId == null) {
        _errorMessage = response['message']?.toString() ?? 'Daxil olmaq mümkün olmadı.';
        return false;
      }
      await _saveSession(
        token: token,
        userId: userId,
        name: response['name']?.toString() ?? '',
        email: response['email']?.toString() ?? email,
        phone: response['phone']?.toString() ?? '',
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Daxil olmaq mümkün olmadı.';
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    _startRequest();
    try {
      final response = await repository.register(name, email, password, phone);
      return response['message'] != null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Qeydiyyatı tamamlamaq mümkün olmadı.';
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) =>
      repository.verifyEmailCode(email, code);

  Future<bool> sendPasswordResetEmail(String email) async {
    _startRequest();
    try {
      final response = await repository.sendPasswordResetEmail(email);
      return response['message'] != null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    _startRequest();
    try {
      final response = await repository.resetPassword(email, token, newPassword);
      return response['message'] != null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove('userName'),
      preferences.remove('userEmail'),
      preferences.remove('userPhone'),
      secureSession.clear(),
    ]);
    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    notifyListeners();
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void _startRequest() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _finishRequest() {
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSession({
    required String token,
    required String userId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      secureSession.write(token: token, userId: userId),
      preferences.setString('userName', name),
      preferences.setString('userEmail', email),
      preferences.setString('userPhone', phone),
    ]);
    _token = token;
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _userPhone = phone;
  }
}
