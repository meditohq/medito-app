import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/account/account_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_service_test.mocks.dart';

class _FakeAuthRepository implements AuthRepository {
  int signOutLocallyCalls = 0;
  int signOutCalls = 0;

  @override
  Future<void> signOutLocally() async => signOutLocallyCalls++;

  @override
  Future<bool> signOut() async {
    signOutCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeStatsManager implements StatsManager {
  int clearCalls = 0;

  @override
  Future<void> clearAllStats() async => clearCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockHttpApiService http;
  late _FakeAuthRepository auth;
  late _FakeStatsManager stats;
  late SharedPreferences prefs;
  late AccountService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.userId: 'old-client-id',
      SharedPreferenceConstants.favorites: '[]',
      SharedPreferenceConstants.themePreference: 'dark',
    });
    prefs = await SharedPreferences.getInstance();
    http = MockHttpApiService();
    auth = _FakeAuthRepository();
    stats = _FakeStatsManager();
    service = AccountService(
      httpApiService: http,
      authRepository: auth,
      preferences: prefs,
      statsManager: stats,
    );
  });

  test('sends reason + details and wipes the local account', () async {
    when(
      http.deleteRequest(HTTPConstants.me, body: anyNamed('body')),
    ).thenAnswer((_) async => {'deleted': true});

    await service.deleteAccount(
      reason: DeleteAccountReason.switchingApp,
      details: '  Trying something else ’ 🙏  ',
    );

    final body =
        verify(
              http.deleteRequest(
                HTTPConstants.me,
                body: captureAnyNamed('body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body, {
      'reason': 'switching_app',
      'details': 'Trying something else ’ 🙏',
    });
    verify(http.clearAuthHeader()).called(1);
    expect(auth.signOutLocallyCalls, 1);
    expect(auth.signOutCalls, 0, reason: 'session is already gone');
    expect(stats.clearCalls, 1);
    expect(prefs.getString(SharedPreferenceConstants.userId), isNull);
    expect(prefs.getString(SharedPreferenceConstants.favorites), isNull);
    expect(prefs.getString(SharedPreferenceConstants.themePreference), 'dark');
  });

  test('sends no body when nothing was picked', () async {
    when(
      http.deleteRequest(HTTPConstants.me, body: anyNamed('body')),
    ).thenAnswer((_) async => {'deleted': true});

    await service.deleteAccount(details: '   ');

    verify(http.deleteRequest(HTTPConstants.me, body: null)).called(1);
  });

  test('keeps the user signed in when the server fails', () async {
    when(
      http.deleteRequest(HTTPConstants.me, body: anyNamed('body')),
    ).thenThrow(Exception('500'));

    await expectLater(
      service.deleteAccount(reason: DeleteAccountReason.other),
      throwsException,
    );

    verifyNever(http.clearAuthHeader());
    expect(auth.signOutLocallyCalls, 0);
    expect(prefs.getString(SharedPreferenceConstants.userId), 'old-client-id');
  });

  test('treats a response without deleted:true as a failure', () async {
    when(
      http.deleteRequest(HTTPConstants.me, body: anyNamed('body')),
    ).thenAnswer((_) async => {});

    await expectLater(service.deleteAccount(), throwsException);
    expect(auth.signOutLocallyCalls, 0);
  });
}
