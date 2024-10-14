import 'package:medito/models/models.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pack_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<PackItemsModel>> fetchAllPacks(FetchAllPacksRef ref) {
  var packRepository = ref.watch(packRepositoryProvider);
  return packRepository.fetchAllPacks();
}

@riverpod
class Pack extends _$Pack {
  @override
  AsyncValue<PackModel> build({required String packId}) {
    fetchPacks(packId: packId);

    return const AsyncLoading();
  }

  Future<void> fetchPacks({required String packId}) async {
    final packRepository = ref.read(packRepositoryProvider);
    final statsManager = StatsManager();

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      var pack = await packRepository.fetchPacks(packId);
      var localStats = await statsManager.localAllStats;
      var tracksChecked = localStats.tracksChecked ?? [];

      var updatedItems = pack.items.map((item) {
        return item.copyWith(isCompleted: tracksChecked.contains(item.id));
      }).toList();

      return pack.copyWith(items: updatedItems);
    });

    ref.keepAlive();
  }

  Future<void> toggleIsComplete({
    required String audioFileId,
    required String trackId,
    required bool isComplete,
  }) async {
    if (isComplete) {
      await StatsManager().removeTrackChecked(trackId);
    } else {
      await StatsManager().addTrackChecked(trackId);
    }

    state = state.whenData((pack) {
      var updatedItems = pack.items.map((item) {
        if (item.id == trackId) {
          return item.copyWith(isCompleted: !isComplete);
        }
        return item;
      }).toList();

      return pack.copyWith(items: updatedItems);
    });
  }
}
