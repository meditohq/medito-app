import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_provider.g.dart';

@riverpod
Future<StatsModel> remoteStats(RemoteStatsRef ref) {
  ref.keepAlive();

  return ref.watch(statsRepositoryProvider).fetchStatsFromRemote();
}

@riverpod
Future<TransferStatsModel?> localStats(LocalStatsRef ref) {
  return ref.watch(statsRepositoryProvider).fetchStatsFromPreference();
}

final postLocalStatsProvider = StateNotifierProvider<PostLocalStatsNotifier,
    AsyncValue<TransferStatsModel?>>((ref) {
  return PostLocalStatsNotifier(ref);
});

//ignore: prefer-match-file-name
class PostLocalStatsNotifier
    extends StateNotifier<AsyncValue<TransferStatsModel?>> {
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
        var event = EventsModel(
          name: EventTypes.transferStats,
          payload: stats.toJson(),
        );

        await ref
            .read(eventsProvider(event: event.toJson()).future)
            .then((_) async {
          await statsProvider.removeStatsFromPreference();
        });
      }

      return stats;
    });
  }
}
