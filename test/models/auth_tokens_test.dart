import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/auth/auth_tokens.dart';

void main() {
  group('AuthTokens', () {
    test('Creates an instance with all properties', () {
      const accessToken = 'test-access-token';
      const refreshToken = 'test-refresh-token';
      const expiresIn = 900;
      const clientId = 'test-client-id';

      final tokens = AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        clientId: clientId,
      );

      expect(tokens.accessToken, equals(accessToken));
      expect(tokens.refreshToken, equals(refreshToken));
      expect(tokens.expiresIn, equals(expiresIn));
      expect(tokens.clientId, equals(clientId));
    });

    test('Creates an instance from JSON', () {
      final json = {
        'access_token': 'test-access-token',
        'refresh_token': 'test-refresh-token',
        'expires_in': 900,
        'client_id': 'test-client-id',
      };

      final tokens = AuthTokens.fromJson(json);

      expect(tokens.accessToken, equals(json['access_token']));
      expect(tokens.refreshToken, equals(json['refresh_token']));
      expect(tokens.expiresIn, equals(json['expires_in']));
      expect(tokens.clientId, equals(json['client_id']));
    });

    test('Converts instance to JSON', () {
      final tokens = AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresIn: 900,
        clientId: 'test-client-id',
      );

      final json = tokens.toJson();

      expect(json['access_token'], equals(tokens.accessToken));
      expect(json['refresh_token'], equals(tokens.refreshToken));
      expect(json['expires_in'], equals(tokens.expiresIn));
      expect(json['client_id'], equals(tokens.clientId));
    });

    test('Checks equality correctly', () {
      final tokens1 = AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresIn: 900,
        clientId: 'test-client-id',
      );

      final tokens2 = AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresIn: 900,
        clientId: 'test-client-id',
      );

      final tokens3 = AuthTokens(
        accessToken: 'different-access-token',
        refreshToken: 'test-refresh-token',
        expiresIn: 900,
        clientId: 'test-client-id',
      );

      expect(tokens1 == tokens2, isTrue);
      expect(tokens1 == tokens3, isFalse);
      expect(tokens1.hashCode == tokens2.hashCode, isTrue);
    });

    test('isExpired returns true when token is expired', () async {
      // Create a token with very short expiry
      final token = AuthTokens(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresIn: 1, // 1 second
        clientId: 'test-client-id',
      );

      // Wait a bit to ensure it's expired
      await Future.delayed(const Duration(milliseconds: 1100));

      // Verify it shows as expired
      expect(token.isExpired, isTrue);
    });

    test('isExpired returns false for non-expired token', () {
      // Create a token with long expiry
      final token = AuthTokens(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresIn: 3600, // 1 hour
        clientId: 'test-client-id',
      );

      // Verify it doesn't show as expired
      expect(token.isExpired, isFalse);
    });

    test('refreshedWith creates a new token with updated values', () {
      // Create an original token
      final originalToken = AuthTokens(
        accessToken: 'old-token',
        refreshToken: 'refresh-token',
        expiresIn: 900,
        clientId: 'client-id',
        email: 'test@example.com',
      );

      // Create a refreshed token
      final refreshedToken = originalToken.refreshedWith(
        accessToken: 'new-token',
        expiresIn: 1800,
      );

      // Verify the refreshed token has updated values
      expect(refreshedToken.accessToken, equals('new-token'));
      expect(refreshedToken.expiresIn, equals(1800));

      // Verify other values are preserved
      expect(refreshedToken.refreshToken, equals('refresh-token'));
      expect(refreshedToken.clientId, equals('client-id'));
      expect(refreshedToken.email, equals('test@example.com'));

      // Verify they are different objects
      expect(refreshedToken, isNot(same(originalToken)));
    });

    test('fromJson correctly parses API response', () {
      // Sample API response JSON
      final json = {
        'access_token': 'jwt-token-string',
        'refresh_token': 'refresh-token-string',
        'expires_in': 900,
        'client_id': 'client-id',
        'email': 'user@example.com',
      };

      // Create token from JSON
      final token = AuthTokens.fromJson(json);

      // Verify all properties are correctly parsed
      expect(token.accessToken, equals('jwt-token-string'));
      expect(token.refreshToken, equals('refresh-token-string'));
      expect(token.expiresIn, equals(900));
      expect(token.clientId, equals('client-id'));
      expect(token.email, equals('user@example.com'));
    });
  });
}
