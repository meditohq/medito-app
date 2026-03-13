import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pack_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<PackItemsModel>> fetchAllPacks(Ref ref) {
  var packRepository = ref.watch(packRepositoryProvider);
  return packRepository
      .fetchAllPacks()
      .then((packs) => packs.expand((pack) => pack.items).toList());
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

    try {
      var pack = await packRepository.fetchPacks(packId);
      if (!ref.mounted) return;

      var localStats = await statsManager.localAllStats;
      if (!ref.mounted) return;

      var tracksChecked = localStats.tracksChecked ?? [];

      var updatedItems = pack.items.map((item) {
        return item.copyWith(isCompleted: tracksChecked.contains(item.id));
      }).toList();

      state = AsyncData(pack.copyWith(items: updatedItems));
    } catch (error, stackTrace) {
      if (!ref.mounted) return;

      if (error is AppError) {
        state = AsyncError(error, stackTrace);
      } else {
        state = AsyncError(const UnknownError(), stackTrace);
      }
    }

    if (ref.mounted) ref.keepAlive();
  }

  Future<void> toggleIsComplete({
    required String audioFileId,
    required String trackId,
    required bool isComplete,
  }) async {
    final statsManager = StatsManager();
    await statsManager.initialize();
    if (!ref.mounted) return;

    if (isComplete) {
      await statsManager.removeTrackChecked(trackId);
    } else {
      await statsManager.addTrackChecked(trackId);
    }
    if (!ref.mounted) return;

    // Refresh stats provider from local to ensure UI shows updated stats
    try {
      await ref.read(statsProvider.notifier).refreshFromLocal();
    } catch (_) {
      // Silently fail if refresh fails - the local state update is more important
    }
    if (!ref.mounted) return;

    // Refresh upNextProvider to update the Up Next widget
    try {
      await ref.read(upNextProvider.notifier).refresh();
    } catch (_) {
      // Silently fail if refresh fails
    }
    if (!ref.mounted) return;

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
