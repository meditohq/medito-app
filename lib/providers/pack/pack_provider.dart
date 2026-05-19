import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pack_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<PackItemsModel>> fetchAllPacks(Ref ref) {
  var packRepository = ref.watch(packRepositoryProvider);
  return packRepository
      .fetchAllPacks()
      .then((packs) => packs.expand((pack) => pack.items).toList());
}

/// Raw pack fetched from the API. Refresh this provider for pull-to-refresh
/// or error-retry; it doesn't watch stats, so completion changes don't
/// trigger a re-fetch.
@Riverpod(keepAlive: true)
Future<PackModel> packData(Ref ref, {required String packId}) {
  return ref.read(packRepositoryProvider).fetchPacks(packId);
}

/// View-facing pack with per-item completion derived from local stats.
/// `build` returns an `AsyncValue` directly (synchronous notifier), so when
/// [statsProvider] fires the provider rebuilds without dropping into
/// `AsyncLoading` — the pack screen no longer flickers on return from the
/// player.
@Riverpod(keepAlive: true)
class Pack extends _$Pack {
  @override
  AsyncValue<PackModel> build({required String packId}) {
    final rawPack = ref.watch(packDataProvider(packId: packId));
    final stats = ref.watch(statsProvider);
    final completed = stats.value?.tracksChecked ?? const <String>[];

    return rawPack.whenData(
      (pack) => pack.copyWith(
        items: pack.items
            .map((item) =>
                item.copyWith(isCompleted: completed.contains(item.id)))
            .toList(),
      ),
    );
  }

  /// Optimistically toggles a track's completion in local stats, then asks
  /// the stats provider to refresh from local. The refresh propagates here
  /// automatically via the [statsProvider] watch above.
  Future<void> toggleIsComplete({
    required String audioFileId,
    required String trackId,
    required bool isComplete,
  }) async {
    final statsManager = ref.read(statsManagerProvider);
    await statsManager.initialize();
    if (!ref.mounted) return;

    if (isComplete) {
      await statsManager.removeTrackChecked(trackId);
    } else {
      await statsManager.addTrackChecked(trackId);
    }
    if (!ref.mounted) return;

    try {
      await ref.read(statsProvider.notifier).refreshFromLocal();
    } catch (_) {
      // Best-effort: even if stats refresh fails, the local toggle stuck.
    }
    if (!ref.mounted) return;

    try {
      await ref.read(upNextProvider.notifier).refresh();
    } catch (_) {
      // Best-effort: up-next is non-critical.
    }
  }
}
