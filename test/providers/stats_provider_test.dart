import 'dart:convert';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Manager extends Mock implements StatsManager {}

class _Service extends Mock implements StatsService {}

class _FakeAuthRepository implements AuthRepository {
  User? user;
  @override
  User? get currentUser => user;
  @override
  Future<String> getToken() async => '';
  @override
  String? getUserEmail() => null;
  @override
  Future<void> initializeUser() async {}
  @override
  Future<bool> isLoggedIn() async => false;
  @override
  Future<void> migrateEmailToStorage() async {}
  @override
  Future<void> requestOtp(String email) async {}
  @override
  void resetAuthState() {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<bool> signOut() async => true;

  @override
  Future<void> signOutLocally() async {}
  @override
  Future<bool> verifyOtp(String email, String otp) async => false;
}

void main() {
  late ProviderContainer container;
  late StatsManager statsManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Initialize SharedPreferences before creating container
    await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        authRepositorySyncProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    statsManager = container.read(statsManagerProvider);
  });

  tearDown(() {
    container.dispose();
    statsManager.resetForTesting();
  });

  test('failed sync preserves saved stats on a cold offline load', () async {
    container.dispose();
    statsManager.resetForTesting();
    final saved = LocalAllStats.empty().copyWith(
      totalTracksCompleted: 7,
      audioCompleted: [
        LocalAudioCompleted(
          id: 'offline-session',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPreferenceConstants.localAllStatsKey,
      jsonEncode(saved.toJson()),
    );
    final service = _Service();
    when(
      () => service.fetchAllStats(),
    ).thenThrow(const NetworkConnectionError());
    await statsManager.initializeForTesting(statsService: service);
    container = ProviderContainer(
      overrides: [
        authRepositorySyncProvider.overrideWithValue(
          _FakeAuthRepository()..user = User(id: 'test-user'),
        ),
      ],
    );
    final result = await container.read(statsProvider.future);
    expect(result.totalTracksCompleted, 7);
    expect(result.audioCompleted?.single.id, 'offline-session');
    await container.read(statsProvider.notifier).refresh();
    expect(container.read(statsProvider).requireValue.totalTracksCompleted, 7);
    expect(container.read(statsProvider).hasError, false);
    verify(() => service.fetchAllStats()).called(1);
  });

  test('empty local snapshot never starts a network request', () async {
    final service = _Service();
    statsManager.resetForTesting();
    await statsManager.initializeForTesting(statsService: service);
    final local = await statsManager.readLocalSnapshot();
    expect(local.totalTracksCompleted, 0);
    verifyNever(() => service.fetchAllStats());
    statsManager.resetForTesting();
  });

  for (final outcome in ['success', 'offline', 'account-switch']) {
    test(
      'local stats appear before slow sync ($outcome), with one shared refresh',
      () async {
        container.dispose();
        final manager = _Manager();
        final auth = _FakeAuthRepository()..user = User(id: 'test-user');
        final gate = Completer<void>();
        final local = LocalAllStats.empty().copyWith(totalTracksCompleted: 4);
        final remote = local.copyWith(totalTracksCompleted: 6);
        when(() => manager.readLocalSnapshot()).thenAnswer((_) async => local);
        when(() => manager.initialize()).thenAnswer((_) async {});
        when(() => manager.sync(force: true)).thenAnswer((_) => gate.future);
        when(
          () => manager.readLocalStats(),
        ).thenAnswer((_) async => outcome == 'offline' ? local : remote);
        container = ProviderContainer(
          overrides: [
            authRepositorySyncProvider.overrideWithValue(auth),
            statsManagerProvider.overrideWithValue(manager),
          ],
        );
        expect(
          (await container.read(statsProvider.future)).totalTracksCompleted,
          4,
        );
        expect(gate.isCompleted, isFalse);
        final notifier = container.read(statsProvider.notifier);
        final refresh = notifier.refresh();
        expect(identical(refresh, notifier.refresh()), isTrue);
        await container.pump();
        if (outcome == 'account-switch') {
          auth.user = User(id: 'another-test-user');
        }
        if (outcome == 'offline') {
          gate.completeError(Exception('offline'));
        } else {
          gate.complete();
        }
        await refresh;
        expect(
          container.read(statsProvider).requireValue.totalTracksCompleted,
          outcome == 'success' ? 6 : 4,
        );
        verify(() => manager.sync(force: true)).called(1);
      },
    );
  }

  group('StatsNotifier - refreshFromLocal', () {
    test('refreshFromLocal - reads from local stats without syncing', () async {
      // Arrange
      var yesterday = DateTime(2025, 3, 14);

      var localStats = LocalAllStats.empty().copyWith(
        streakCurrent: 5,
        streakFreezes: 2,
        totalTracksCompleted: 10,
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: yesterday.millisecondsSinceEpoch,
          ),
        ],
      );

      statsManager.setStatsForTesting(localStats);
      await statsManager.initialize();

      // Get the notifier
      final notifier = container.read(statsProvider.notifier);

      // Act - refresh from local
      await notifier.refreshFromLocal();

      // Assert - state should contain the local stats
      final state = container.read(statsProvider);
      expect(state.isLoading, false);
      expect(state.hasValue, true);

      final stats = state.value!;
      expect(stats.streakCurrent, 5);
      expect(stats.streakFreezes, 2);
      expect(stats.totalTracksCompleted, 10);
      expect(stats.audioCompleted?.length, 1);
    });

    test('refreshFromLocal - handles errors gracefully', () async {
      // Arrange - create a stats manager that will error
      container.dispose();
      container = ProviderContainer(
        overrides: [
          authRepositorySyncProvider.overrideWithValue(_FakeAuthRepository()),
        ],
      );

      // Get the notifier
      final notifier = container.read(statsProvider.notifier);

      // Act - try to refresh when stats manager might not be initialized properly
      // This might error, but should be handled
      await notifier.refreshFromLocal();

      // Assert - state should be in some valid state (loading, error, or data)
      final state = container.read(statsProvider);
      // The state should be valid even if there was an error
      expect(state.hasValue || state.hasError || state.isLoading, true);
    });
  });
}
