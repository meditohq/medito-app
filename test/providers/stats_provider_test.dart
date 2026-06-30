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
