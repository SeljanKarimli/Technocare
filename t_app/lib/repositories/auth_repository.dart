import '../core/api_client.dart';

class AuthRepository {
  final ApiClient _api;

  const AuthRepository(this._api);

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String phone,
  ) => _post('Auth/register', {
        'name': name,
        'email': _email(email),
        'password': password,
        'phone': phone,
      });

  Future<Map<String, dynamic>> login(String email, String password) =>
      _post('Auth/login', {'email': _email(email), 'password': password});

  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) =>
      _post('Auth/forgot-password', {'email': _email(email)});

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String token,
    String newPassword,
  ) => _post('Auth/reset-password', {
        'email': _email(email),
        'token': token,
        'newPassword': newPassword,
      });

  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) =>
      _post('Auth/verify-email', {'email': _email(email), 'code': code});

  Future<Map<String, dynamic>> resendVerificationCode(String email) =>
      _post('Auth/resend-code', {'email': _email(email)});

  static String _email(String value) => value.trim().toLowerCase();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.post(path, body: body);
    return Map<String, dynamic>.from(response as Map);
  }
}
