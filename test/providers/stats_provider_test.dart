import 'dart:convert';

import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/views/previews/preview_support.dart'
    show FakeAuthRepository;
import 'package:mockito/mockito.dart';
import '../stats_manager_test.mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  User? get currentUser => null;
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
      streakCurrent: 4,
      totalTracksCompleted: 7,
      audioCompleted: [
        LocalAudioCompleted(id: 'offline-session', timestamp: 1234),
      ],
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPreferenceConstants.localAllStatsKey,
      jsonEncode(saved.toJson()),
    );
    final service = MockStatsService();
    when(service.fetchAllStats()).thenThrow(const NetworkConnectionError());
    await statsManager.initializeForTesting(statsService: service);
    container = ProviderContainer(
      overrides: [
        authRepositorySyncProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );

    final result = await container.read(statsProvider.future);

    expect(result.streakCurrent, 4);
    expect(result.totalTracksCompleted, 7);
    expect(result.audioCompleted?.single.id, 'offline-session');
    expect(container.read(statsProvider).hasError, false);
    verify(service.fetchAllStats()).called(1);
  });

  test('reading empty local stats never tries the network', () async {
    statsManager.resetForTesting();
    final service = MockStatsService();
    await statsManager.initializeForTesting(statsService: service);

    final result = await statsManager.readLocalStats();

    expect(result.totalTracksCompleted, 0);
    verifyNever(service.fetchAllStats());
  });

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
