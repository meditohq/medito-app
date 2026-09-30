import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/watch_sync_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../stats_manager_test.mocks.dart';

class _LocalStats extends StatsNotifier {
  @override
  Future<LocalAllStats> build() => ref.read(statsManagerProvider).localAllStats;
}

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.empty();
  bool failWrites = true;
  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (failWrites &&
        key.endsWith(SharedPreferenceConstants.localAllStatsKey)) {
      return Future.value(false);
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('medito.app/watch');
  late ProviderContainer container;
  late StatsManager manager;
  late MockStatsService service;
  late List<Map<String, Object>> pending;
  late SharedPreferences prefs;
  bool failAck = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.isLoggedIn: true,
      SharedPreferenceConstants.userId: 'account',
      'healthAuthRequested': true,
    });
    prefs = await SharedPreferences.getInstance();
    manager = StatsManager()..resetForTesting();
    service = MockStatsService();
    await manager.initializeForTesting(statsService: service);
    manager.setStatsForTesting(LocalAllStats.empty());
    failAck = false;
    pending = [
      {
        'trackId': 'watch-track',
        'timestamp': DateTime(2026, 9, 30, 12).millisecondsSinceEpoch,
        'duration': 600000,
        'accountId': 'account',
      },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'takePendingSessions') return pending.toList();
          if (call.method == 'acknowledgeSessions') {
            // The acknowledgement must follow the durable local stats save.
            if (pending.single['accountId'] == 'account') {
              expect(
                prefs.getString(SharedPreferenceConstants.localAllStatsKey),
                isNotNull,
              );
            }
            if (failAck) throw PlatformException(code: 'ack_failed');
            pending.clear();
            return true;
          }
          throw StateError('Unexpected method ${call.method}');
        });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        statsManagerProvider.overrideWithValue(manager),
        statsProvider.overrideWith(_LocalStats.new),
      ],
    );
  });

  tearDown(() async {
    // Let best-effort upload/widget callbacks settle before resetting singletons.
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    manager.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('records without HomeView and acknowledges after saving', () async {
    await container.read(watchCompletionSyncProvider).drainPendingSessions();
    expect(pending, isEmpty);
    expect(manager.currentStats!.totalTracksCompleted, 1);
  });

  test(
    'failed acknowledgement retains queue; retry does not double count',
    () async {
      final sync = container.read(watchCompletionSyncProvider);
      failAck = true;
      await sync.drainPendingSessions();
      expect(pending, hasLength(1));
      expect(manager.currentStats!.totalTracksCompleted, 1);
      failAck = false;
      await sync.drainPendingSessions();
      expect(pending, isEmpty);
      expect(manager.currentStats!.totalTracksCompleted, 1);
      expect(manager.currentStats!.totalTimeListened, 600000);
    },
  );

  test(
    'offline upload does not prevent local recording or acknowledgement',
    () async {
      when(service.postStats(any)).thenThrow(Exception('offline'));
      await container.read(watchCompletionSyncProvider).drainPendingSessions();
      expect(pending, isEmpty);
      expect(manager.currentStats!.totalTracksCompleted, 1);
    },
  );

  test(
    'failed local save retains queue and rolls back; retry records once',
    () async {
      final store = _FailingStore();
      SharedPreferencesStorePlatform.instance = store;
      final sync = container.read(watchCompletionSyncProvider);
      await sync.drainPendingSessions();
      expect(pending, hasLength(1));
      expect(manager.currentStats!.totalTracksCompleted, 0);
      expect(manager.currentStats!.tracksChecked, isEmpty);
      store.failWrites = false;
      await sync.drainPendingSessions();
      expect(pending, isEmpty);
      expect(manager.currentStats!.totalTracksCompleted, 1);
      expect(manager.currentStats!.totalTimeListened, 600000);
    },
  );

  test('signed-out app leaves sessions queued', () async {
    await prefs.setBool(SharedPreferenceConstants.isLoggedIn, false);
    await container.read(watchCompletionSyncProvider).drainPendingSessions();
    expect(pending, hasLength(1));
    expect(manager.currentStats!.totalTracksCompleted, 0);
  });

  test(
    'completion from another account does not alter this account stats',
    () async {
      pending.single['accountId'] = 'old-account';
      await container.read(watchCompletionSyncProvider).drainPendingSessions();
      expect(pending, isEmpty);
      expect(manager.currentStats!.totalTracksCompleted, 0);
    },
  );
}
