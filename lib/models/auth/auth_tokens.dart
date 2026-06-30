// Business logic model for auth tokens
import 'package:medito/utils/logger.dart';

final dev = const AppLoggerAdapter('AUTH_TOKENS');

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String clientId;
  final String? email;

  // Calculate expiry time when created
  final DateTime createdAt;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.clientId,
    this.email,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    // One-line debug log (already kDebugMode-gated by AppLogger). Use
    // `toString()` for the detailed dump when needed at a callsite.
    dev.log(
      'Created tokens (accessToken: ${_safeSubstring(accessToken, 0, 10)}…, '
      'expiresIn: ${expiresIn}s, clientId: $clientId, email: $email)',
      level: 1000,
    );
  }

  // Helper method to safely get a substring
  static String _safeSubstring(String text, int start, int end) {
    if (text.isEmpty) return '';
    int safeEnd = end > text.length ? text.length : end;
    return text.substring(start, safeEnd);
  }

  // Convert from API response
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      clientId: json['client_id'] as String,
      email: json['email'] as String?,
    );
  }

  // Convert to JSON for API requests or storage
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'client_id': clientId,
      if (email != null) 'email': email,
    };
  }

  // Check if token is expired or about to expire (with 30s buffer)
  bool get isExpired {
    final expiration = createdAt.add(Duration(seconds: expiresIn));
    final isExpired = DateTime.now().isAfter(expiration);
    dev.log(
      '[AUTH_TOKENS] Token expired check: $isExpired (expiration: $expiration)',
      level: 1000,
    );
    return isExpired;
  }

  // Create a new instance with refreshed access token
  AuthTokens refreshedWith({
    required String accessToken,
    required int expiresIn,
  }) {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      clientId: clientId,
      email: email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokens &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresIn == other.expiresIn &&
          clientId == other.clientId &&
          email == other.email;

  @override
  int get hashCode =>
      accessToken.hashCode ^
      refreshToken.hashCode ^
      expiresIn.hashCode ^
      clientId.hashCode ^
      (email?.hashCode ?? 0);

  @override
  String toString() {
    return 'AuthTokens{accessToken: ${_safeSubstring(accessToken, 0, 10)}..., '
        'refreshToken: ${_safeSubstring(refreshToken, 0, 5)}..., '
        'expiresIn: $expiresIn, '
        'createdAt: $createdAt, '
        'clientId: $clientId, '
        'email: $email}';
  }

  // Static method to help with debugging token refresh
  static void logTokenDifferences(AuthTokens? oldTokens, AuthTokens newTokens) {
    if (oldTokens == null) {
      dev.log('[AUTH_TOKENS] No old tokens to compare with', level: 1000);
      return;
    }

    dev.log('[AUTH_TOKENS] Comparing tokens', level: 1000);

    // Check if email changed
    if (oldTokens.email != newTokens.email) {
      dev.log(
        '[AUTH_TOKENS] ⚠️ EMAIL CHANGED from ${oldTokens.email} to ${newTokens.email}',
        level: 1000,
      );
    } else {
      dev.log('[AUTH_TOKENS] Email unchanged: ${newTokens.email}', level: 1000);
    }

    // Check if client ID changed
    if (oldTokens.clientId != newTokens.clientId) {
      dev.log(
        '[AUTH_TOKENS] ⚠️ CLIENT ID CHANGED from ${oldTokens.clientId} to ${newTokens.clientId}',
        level: 1000,
      );
    } else {
      dev.log(
        '[AUTH_TOKENS] Client ID unchanged: ${newTokens.clientId}',
        level: 1000,
      );
    }

    // Access token always changes in a refresh
    dev.log(
      '[AUTH_TOKENS] New access token prefix: ${_safeSubstring(newTokens.accessToken, 0, 10)}...',
      level: 1000,
    );

    // Check expiration time
    dev.log(
      '[AUTH_TOKENS] New expiration: ${newTokens.expiresIn} seconds',
      level: 1000,
    );
    dev.log(
      '[AUTH_TOKENS] Creation timestamp: ${newTokens.createdAt}',
      level: 1000,
    );
  }
}
