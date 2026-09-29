// Cold-start token handling:
//
//   1. HttpApiService waits for an access token before sending a request
//      that has no auth header (early GET /stats, /packs, /home used to go
//      out token-less, 401, then refresh in parallel with the auth repo).
//   2. AuthApiService shares one IN-FLIGHT refresh per refresh token, across
//      its instances. The server does not rotate refresh tokens, so a
//      finished refresh must never be reused (its access token expires).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApiService extends Mock implements AuthApiService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  group('HttpApiService token wait', () {
    late HttpApiService service;

    setUp(() {
      service = HttpApiService.internal(authService: _MockAuthApiService());
    });

    test('asks for a token when the auth header is missing', () async {
      var calls = 0;
      service.setTokenSupplier(() async {
        calls++;
        service.setAuthHeader('fresh-access-token');
      });

      await service.awaitAuthHeaderForTesting();
      await service.awaitAuthHeaderForTesting();

      expect(calls, 1);
    });

    test('does not ask when a header is already set', () async {
      var calls = 0;
      service.setAuthHeader('existing-token');
      service.setTokenSupplier(() async => calls++);

      await service.awaitAuthHeaderForTesting();

      expect(calls, 0);
    });

    test('a failing supplier does not fail the request', () async {
      service.setTokenSupplier(() async => throw Exception('offline'));

      await expectLater(service.awaitAuthHeaderForTesting(), completes);
    });

    test('concurrent requests share one supplier call', () async {
      var calls = 0;
      final gate = Completer<void>();
      service.setTokenSupplier(() async {
        calls++;
        await gate.future;
        service.setAuthHeader('fresh-access-token');
      });

      final waits = [
        service.awaitAuthHeaderForTesting(),
        service.awaitAuthHeaderForTesting(),
        service.awaitAuthHeaderForTesting(),
      ];
      gate.complete();
      await Future.wait(waits);

      expect(calls, 1);
    });

    test(
      'after a failure, requests stop waiting until a token is set',
      () async {
        var calls = 0;
        service.setTokenSupplier(() async {
          calls++;
          throw const NetworkConnectionError();
        });

        await service.awaitAuthHeaderForTesting();
        await service.awaitAuthHeaderForTesting();
        expect(calls, 1, reason: 'offline: the second request must not wait');

        service.setAuthHeader('fresh-access-token');
        service.clearAuthHeader();
        await service.awaitAuthHeaderForTesting();
        expect(calls, 2, reason: 'a successful sign-in ends the cooldown');
      },
    );
  });

  group('HttpApiService refresh after sign-out', () {
    test('a refresh that lands after clearLocalAuth is dropped', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.isLoggedIn: true,
      });
      final auth = _MockAuthApiService();
      final service = HttpApiService.internal(authService: auth);
      final pending = Completer<AuthTokens>();
      when(() => auth.getStoredRefreshToken()).thenAnswer((_) async => 'R');
      when(() => auth.refreshToken('R')).thenAnswer((_) => pending.future);
      when(() => auth.clearAuthTokens()).thenAnswer((_) async {});

      final refresh = service.refreshTokenForTesting();
      await pumpEventQueue();
      await service.clearLocalAuth();
      pending.complete(
        AuthTokens(
          accessToken: 'deleted-account-access',
          refreshToken: 'R',
          expiresIn: 7200,
          clientId: 'deleted-client',
        ),
      );

      await expectLater(refresh, throwsA(isA<UnauthorizedError>()));
      expect((await service.diagnoseSecurity())['has_auth_header'], isFalse);
    });
  });

  group('AuthApiService refresh sharing', () {
    late HttpServer server;
    late int hits;
    late int status;
    late Completer<void> gate;
    late _MockSecureStorageService storage;
    late String clientId;
    late String? email;

    AuthApiService newService() => AuthApiService(
      secureStorage: storage,
      baseUrl: 'http://${server.address.host}:${server.port}/',
      customApiKey: 'test-key',
      crashlyticsService: _MockCrashlyticsService(),
    );

    setUp(() async {
      AuthApiService.clearRefreshCache();
      hits = 0;
      status = 200;
      gate = Completer<void>()..complete();
      clientId = 'client';
      email = null;
      storage = _MockSecureStorageService();
      when(() => storage.storeRefreshToken(any())).thenAnswer((_) async {});
      when(() => storage.clearRefreshToken()).thenAnswer((_) async {});

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        hits++;
        final sent = jsonDecode(await utf8.decodeStream(request)) as Map;
        await gate.future;
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            status == 200
                ? {
                    'access_token': 'access-$hits',
                    // Like the real server: the same refresh token comes back.
                    'refresh_token': sent['refresh_token'],
                    'expires_in': 7200,
                    'client_id': clientId,
                    'email': email,
                  }
                : {'error': 'server'},
          ),
        );
        await request.response.close();
      });
    });

    tearDown(() async {
      AuthApiService.clearRefreshCache();
      await server.close(force: true);
    });

    test(
      'concurrent refreshes from two instances hit the server once',
      () async {
        gate = Completer<void>();
        final a = newService().refreshToken('R');
        final b = newService().refreshToken('R');
        gate.complete();

        final results = await Future.wait([a, b]);

        expect(hits, 1);
        expect(results[0].accessToken, results[1].accessToken);
      },
    );

    test(
      'a refresh after the previous one finished reaches the server',
      () async {
        final first = await newService().refreshToken('R');
        final again = await newService().refreshToken('R');

        expect(hits, 2);
        expect(again.accessToken, isNot(first.accessToken));
      },
    );

    test(
      'clearRefreshCache stops later callers joining the old refresh',
      () async {
        gate = Completer<void>();
        final before = newService().refreshToken('R');
        AuthApiService.clearRefreshCache();
        final after = newService().refreshToken('R');
        gate.complete();
        await Future.wait([before, after]);

        expect(hits, 2);
      },
    );

    test('an email is not carried over to a different client', () async {
      final api = newService();
      email = 'old@example.com';
      clientId = 'email-client';
      await api.refreshToken('R-email');

      email = null;
      clientId = 'anonymous-client';
      final anon = await api.refreshToken('R-anon');

      expect(anon.email, isNull);
    });

    test(
      'the same client keeps its email when the response omits it',
      () async {
        final api = newService();
        email = 'user@example.com';
        await api.refreshToken('R');

        email = null;
        final again = await api.refreshToken('R');

        expect(again.email, 'user@example.com');
      },
    );

    test('a failed refresh is not cached', () async {
      status = 500;
      await expectLater(newService().refreshToken('R'), throwsA(anything));

      status = 200;
      await newService().refreshToken('R');

      expect(hits, 2);
    });
  });
}
