import 'dart:developer' as dev;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Interface for FlutterSecureStorage to make testing easier
class SecureStorage {
  final FlutterSecureStorage storage;

  SecureStorage({FlutterSecureStorage? storage})
      : this.storage = storage ?? const FlutterSecureStorage();

  Future<void> write({required String key, required String? value}) {
    return storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) {
    return storage.read(key: key);
  }

  Future<void> delete({required String key}) {
    return storage.delete(key: key);
  }
}

class SecureStorageService {
  static const _refreshTokenKey = 'medito_refresh_token';
  final SecureStorage _storage;

  SecureStorageService({SecureStorage? storage})
      : _storage = storage ?? SecureStorage();

  Future<void> storeRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      dev.log('[SECURE_STORAGE] Refresh token stored successfully');
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error storing refresh token', error: e);
      rethrow;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _refreshTokenKey);
      dev.log(
          '[SECURE_STORAGE] Refresh token ${token != null ? 'found' : 'not found'}');
      return token;
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error retrieving refresh token', error: e);
      return null;
    }
  }

  Future<void> clearRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
      dev.log('[SECURE_STORAGE] Refresh token cleared');
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error clearing refresh token', error: e);
    }
  }
}
