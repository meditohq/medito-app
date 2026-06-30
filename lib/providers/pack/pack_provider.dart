import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pack_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<PackItemsModel>> fetchAllPacks(Ref ref) {
  var packRepository = ref.watch(packRepositoryProvider);
  return packRepository.fetchAllPacks().then(
    (packs) => packs.expand((pack) => pack.items).toList(),
  );
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
            .map(
              (item) => item.copyWith(isCompleted: completed.contains(item.id)),
            )
            .toList(),
      ),
    );
  }

  /// Sets a track's completion to an absolute value in local stats, then asks
  /// the stats provider to refresh from local. The refresh propagates here
  /// automatically via the [statsProvider] watch above.
  ///
  /// Returns `true` when the change was persisted, `false` on failure — the
  /// caller (the row's optimistic toggle) uses this to revert its UI.
  /// Taking an absolute `complete` rather than toggling keeps rapid repeated
  /// taps deterministic: each call states the desired end state outright.
  Future<bool> setIsComplete({
    required String trackId,
    required bool complete,
  }) async {
    try {
      final statsManager = ref.read(statsManagerProvider);
      await statsManager.initialize();
      if (!ref.mounted) return false;

      if (complete) {
        await statsManager.addTrackChecked(trackId);
      } else {
        await statsManager.removeTrackChecked(trackId);
      }
      if (!ref.mounted) return true;

      try {
        await ref.read(statsProvider.notifier).refreshFromLocal();
      } catch (_) {
        // Best-effort: even if stats refresh fails, the local change stuck.
      }
      // upNextProvider rebuilds reactively via packProvider <- statsProvider,
      // so no explicit refresh is needed here.
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Marks every track in the pack complete (or clears them all) in one
  /// stats write. Backs the "mark all complete/incomplete" button.
  Future<void> markAll({required bool complete}) async {
    final pack = state.value;
    if (pack == null) return;

    final trackIds = pack.items
        .where((item) => item.type == TypeConstants.track)
        .map((item) => item.id)
        .toList();
    if (trackIds.isEmpty) return;

    final statsManager = ref.read(statsManagerProvider);
    await statsManager.initialize();
    if (!ref.mounted) return;

    await statsManager.setTracksChecked(trackIds, checked: complete);
    if (!ref.mounted) return;

    try {
      await ref.read(statsProvider.notifier).refreshFromLocal();
    } catch (_) {
      // Best-effort: the local toggle stuck even if the refresh failed.
    }
  }
}
