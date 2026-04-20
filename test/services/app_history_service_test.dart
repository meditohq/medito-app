import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/history/app_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppHistoryService.recordCurrentVersion', () {
    test('appends first version with timestamp', () async {
      final prefs = await SharedPreferences.getInstance();

      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.17',
        buildNumber: '100',
      );

      final history = AppHistoryService.getVersionHistory(prefs);
      expect(history, hasLength(1));
      expect(history.first['version'], '3.6.17');
      expect(history.first['buildNumber'], '100');
      expect(history.first['firstSeenAt'], isA<String>());
      expect(
        DateTime.parse(history.first['firstSeenAt'] as String),
        isA<DateTime>(),
      );
    });

    test('does not duplicate same version+build', () async {
      final prefs = await SharedPreferences.getInstance();

      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.17',
        buildNumber: '100',
      );
      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.17',
        buildNumber: '100',
      );

      expect(AppHistoryService.getVersionHistory(prefs), hasLength(1));
    });

    test('appends when buildNumber differs', () async {
      final prefs = await SharedPreferences.getInstance();

      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.17',
        buildNumber: '100',
      );
      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.17',
        buildNumber: '101',
      );
      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.18',
        buildNumber: '102',
      );

      final history = AppHistoryService.getVersionHistory(prefs);
      expect(history, hasLength(3));
      expect(
        history.map((e) => '${e['version']}+${e['buildNumber']}').toList(),
        ['3.6.17+100', '3.6.17+101', '3.6.18+102'],
      );
    });
  });

  group('AppHistoryService.recordSignIn', () {
    test('appends sign-in with id, email, timestamp', () async {
      final prefs = await SharedPreferences.getInstance();

      await AppHistoryService.recordSignIn(
        prefs,
        userId: 'client-1',
        email: 'a@example.com',
      );

      final history = AppHistoryService.getSignInHistory(prefs);
      expect(history, hasLength(1));
      expect(history.first['userId'], 'client-1');
      expect(history.first['email'], 'a@example.com');
      expect(
        DateTime.parse(history.first['signedInAt'] as String),
        isA<DateTime>(),
      );
    });

    test('dedups same (userId, email); appends when either differs',
        () async {
      final prefs = await SharedPreferences.getInstance();

      // Same anonymous id (email null) repeats — should only record once.
      await AppHistoryService.recordSignIn(prefs, userId: 'client-1');
      await AppHistoryService.recordSignIn(prefs, userId: 'client-1');

      // Same id with an email attached — new combination, should append.
      await AppHistoryService.recordSignIn(
        prefs,
        userId: 'client-1',
        email: 'a@example.com',
      );

      // New id — should append.
      await AppHistoryService.recordSignIn(
        prefs,
        userId: 'client-2',
        email: 'b@example.com',
      );

      final history = AppHistoryService.getSignInHistory(prefs);
      expect(history, hasLength(3));
      expect(history[0]['userId'], 'client-1');
      expect(history[0]['email'], isNull);
      expect(history[1]['email'], 'a@example.com');
      expect(history[2]['userId'], 'client-2');
    });

    test('accepts null email', () async {
      final prefs = await SharedPreferences.getInstance();

      await AppHistoryService.recordSignIn(
        prefs,
        userId: 'client-1',
        email: null,
      );

      final history = AppHistoryService.getSignInHistory(prefs);
      expect(history.first['email'], isNull);
    });
  });

  group('AppHistoryService decode / robustness', () {
    test('returns empty list when pref is unset', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(AppHistoryService.getVersionHistory(prefs), isEmpty);
      expect(AppHistoryService.getSignInHistory(prefs), isEmpty);
    });

    test('returns empty list when pref contains corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.installedVersionHistory: 'not-json{',
        SharedPreferenceConstants.signedInUserHistory: '{"not":"a list"}',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(AppHistoryService.getVersionHistory(prefs), isEmpty);
      expect(AppHistoryService.getSignInHistory(prefs), isEmpty);
    });
  });

  group('AppHistoryService base64 helpers', () {
    test('empty history returns empty string (not base64 of [])', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(AppHistoryService.getVersionHistoryBase64(prefs), '');
      expect(AppHistoryService.getSignInHistoryBase64(prefs), '');
    });

    test('base64 decodes to the same JSON list', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppHistoryService.recordCurrentVersion(
        prefs,
        version: '3.6.17',
        buildNumber: '100',
      );
      await AppHistoryService.recordSignIn(
        prefs,
        userId: 'client-1',
        email: 'a@example.com',
      );

      final versionB64 = AppHistoryService.getVersionHistoryBase64(prefs);
      final signInB64 = AppHistoryService.getSignInHistoryBase64(prefs);

      final decodedVersions =
          jsonDecode(utf8.decode(base64Decode(versionB64))) as List;
      final decodedSignIns =
          jsonDecode(utf8.decode(base64Decode(signInB64))) as List;

      expect(decodedVersions, hasLength(1));
      expect((decodedVersions.first as Map)['version'], '3.6.17');
      expect(decodedSignIns, hasLength(1));
      expect((decodedSignIns.first as Map)['userId'], 'client-1');
    });
  });
}
