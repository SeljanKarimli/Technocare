import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureSession {
  static const _tokenKey = 'technocare.jwt';
  static const _userIdKey = 'technocare.userId';
  final FlutterSecureStorage _storage;

  SecureSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<void> migrateLegacySession() async {
    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString('jwtToken');
    final legacyUserId = preferences.getString('userId');
    if (legacyToken != null && legacyToken.isNotEmpty && await readToken() == null) {
      await write(token: legacyToken, userId: legacyUserId ?? '');
    }
    await preferences.remove('jwtToken');
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<void> write({required String token, required String userId}) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userIdKey),
    ]);
  }
}
