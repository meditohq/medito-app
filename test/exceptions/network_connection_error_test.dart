import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/exceptions/app_error.dart';

void main() {
  group('NetworkConnectionError.fromSocketException', () {
    test('DNS failure is classified as hostLookup', () {
      final e = NetworkConnectionError.fromSocketException(
        const SocketException(
          'Failed host lookup: \'auth.medito.app\'',
          osError: OSError('No address associated with hostname', 7),
        ),
      );
      expect(e.kind, NetworkFailureKind.hostLookup);
      expect(e.message, contains("Couldn't reach Medito's servers"));
      expect(e.detail, contains('errno 7'));
    });

    test('HttpClient connectionTimeout is classified as connectTimeout', () {
      final e = NetworkConnectionError.fromSocketException(
        const SocketException(
          'HTTP connection timed out after 0:00:30, host: auth.medito.app, port: 443',
        ),
      );
      expect(e.kind, NetworkFailureKind.connectTimeout);
      expect(e.message, contains('timed out'));
    });

    test(
      'refused and reset connections are classified as connectionRefused',
      () {
        for (final se in [
          const SocketException(
            'Connection refused',
            osError: OSError('Connection refused', 111),
          ),
          const SocketException(
            'Connection reset by peer',
            osError: OSError('Connection reset by peer', 104),
          ),
        ]) {
          expect(
            NetworkConnectionError.fromSocketException(se).kind,
            NetworkFailureKind.connectionRefused,
          );
        }
      },
    );

    test('network unreachable keeps the plain offline message', () {
      final e = NetworkConnectionError.fromSocketException(
        const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
        ),
      );
      expect(e.kind, NetworkFailureKind.offline);
      expect(e.message, 'No internet connection');
      expect(e.originalException, isA<SocketException>());
    });

    test('default constructor is unchanged', () {
      const e = NetworkConnectionError();
      expect(e.kind, NetworkFailureKind.offline);
      expect(e.toString(), 'No internet connection');
    });
  });
}
