// Cold-start token handling:
//
//   1. HttpApiService waits for an access token before sending a request
//      that has no auth header (early GET /stats, /packs, /home used to go
//      out token-less, 401, then refresh in parallel with the auth repo).
//   2. AuthApiService shares one refresh per refresh token, across its
//      instances. Refresh tokens rotate, so a second request with the same
//      token must not reach the server.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

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
  });

  group('AuthApiService refresh sharing', () {
    late HttpServer server;
    late int hits;
    late int status;
    late Completer<void> gate;
    late _MockSecureStorageService storage;

    AuthApiService newService() => AuthApiService(
      secureStorage: storage,
      baseUrl: 'http://${server.address.host}:${server.port}/',
      customApiKey: 'test-key',
      crashlyticsService: _MockCrashlyticsService(),
    );

    setUp(() async {
      AuthApiService.resetRefreshCacheForTesting();
      hits = 0;
      status = 200;
      gate = Completer<void>()..complete();
      storage = _MockSecureStorageService();
      when(() => storage.storeRefreshToken(any())).thenAnswer((_) async {});
      when(() => storage.getRefreshToken()).thenAnswer((_) async => 'rotated');

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        hits++;
        await utf8.decodeStream(request);
        await gate.future;
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            status == 200
                ? {
                    'access_token': 'access-$hits',
                    'refresh_token': 'rotated',
                    'expires_in': 900,
                    'client_id': 'client',
                  }
                : {'error': 'server'},
          ),
        );
        await request.response.close();
      });
    });

    tearDown(() async {
      AuthApiService.resetRefreshCacheForTesting();
      await server.close(force: true);
    });

    test(
      'concurrent refreshes from two instances hit the server once',
      () async {
        gate = Completer<void>();
        final a = newService().refreshToken('original');
        final b = newService().refreshToken('original');
        gate.complete();

        final results = await Future.wait([a, b]);

        expect(hits, 1);
        expect(results[0].accessToken, results[1].accessToken);
      },
    );

    test('a spent token reuses the finished refresh', () async {
      final first = await newService().refreshToken('original');
      final again = await newService().refreshToken('original');

      expect(hits, 1);
      expect(again.accessToken, first.accessToken);
    });

    test('a failed refresh is not cached', () async {
      status = 500;
      await expectLater(
        newService().refreshToken('original'),
        throwsA(anything),
      );

      status = 200;
      await newService().refreshToken('original');

      expect(hits, 2);
    });
  });
}
