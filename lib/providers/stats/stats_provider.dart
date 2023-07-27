import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_provider.g.dart';

@riverpod
Future<StatsModel> remoteStats(ref) {
  ref.keepAlive();

  return ref.watch(statsRepositoryProvider).fetchStatsFromRemote();
}

@riverpod
Future<Map<String, dynamic>?> localStats(ref) {
  return ref.watch(statsRepositoryProvider).fetchStatsFromPreference();
}

final postLocalStatsProvider = StateNotifierProvider<PostLocalStatsNotifier,
    AsyncValue<Map<String, dynamic>?>>((ref) {
  return PostLocalStatsNotifier(ref);
});

//ignore: prefer-match-file-name
class PostLocalStatsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  Ref ref;
  PostLocalStatsNotifier(this.ref) : super(const AsyncValue.loading()) {
    postLocalStats();
  }
  Future<void> postLocalStats() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final statsProvider = ref.read(statsRepositoryProvider);
      var stats = await statsProvider.fetchStatsFromPreference();
      if (stats != null) {
        var statsModel = TransferStatsModel(
          currentStreak: stats['currentStreak'],
          minutesListened: stats['minutesListened'],
          listendedSessionsNum: stats['listendedSessionsNum'],
          longestStreak: stats['longestStreak'],
          listenedSessionIds: stats['listenedSessionIds'],
        );
        var event = EventsModel(
          name: EventTypes.transferStats,
          payload: statsModel.toJson(),
        );
        try {
          await ref.read(eventsProvider(event: event.toJson()).future);
          await statsProvider.removeStatsFromPreference();
        } catch (e) {
          rethrow;
        }
      }

      return stats;
    });
  }
}
