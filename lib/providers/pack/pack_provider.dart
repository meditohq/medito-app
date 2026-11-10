import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
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

/// Every pack's track ids (sub-packs included), from `GET /packs/tracks`.
/// Empty on failure: a pack then simply shows no tick, never a wrong one.
@Riverpod(keepAlive: true)
Future<Map<String, List<String>>> packTrackIds(Ref ref) async {
  try {
    return await ref.read(packRepositoryProvider).fetchPackTrackIds();
  } catch (_) {
    return const {};
  }
}

/// Packs the user has seen fully complete on their own device. Backs up
/// [completedPackIds] when the server's track lists are missing or don't match
/// what the pack screen shows.
@Riverpod(keepAlive: true)
class LocallyCompletedPacks extends _$LocallyCompletedPacks {
  @override
  Set<String> build() {
    return ref
            .read(sharedPreferencesProvider)
            .getStringList(SharedPreferenceConstants.locallyCompletedPackIds)
            ?.toSet() ??
        <String>{};
  }

  /// No-op when the value is unchanged, so listeners that call this on every
  /// pack update can't cause a rebuild loop.
  void setComplete(String packId, bool complete) {
    if (state.contains(packId) == complete) return;
    final next = {...state};
    complete ? next.add(packId) : next.remove(packId);
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(
          SharedPreferenceConstants.locallyCompletedPackIds,
          next.toList(),
        );
  }
}

/// True when [pack] has at least one track or sub-pack and all of them are
/// completed. Other item types (links, etc.) are ignored.
bool isPackFullyComplete(PackModel pack) {
  final counted = pack.items.where(
    (i) => i.type == TypeConstants.track || i.type == TypeConstants.pack,
  );
  return counted.isNotEmpty && counted.every((i) => i.isCompleted == true);
}

/// Ids of packs whose tracks are all completed, plus packs recorded complete
/// locally. Completion is per track, so a track shared by several packs
/// counts towards each of them.
@Riverpod(keepAlive: true)
Set<String> completedPackIds(Ref ref) {
  final local = ref.watch(locallyCompletedPacksProvider);
  final packTracks = ref.watch(packTrackIdsProvider).value ?? const {};
  final checked = ref.watch(statsProvider).value?.tracksChecked;
  if (packTracks.isEmpty || checked == null || checked.isEmpty) return local;

  final completed = checked.toSet();
  return {
    ...local,
    for (final entry in packTracks.entries)
      if (entry.value.isNotEmpty && entry.value.every(completed.contains))
        entry.key,
  };
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
    final completedPacks = ref.watch(completedPackIdsProvider);

    return rawPack.whenData(
      (pack) => pack.copyWith(
        items: pack.items
            .map(
              (item) => item.copyWith(
                isCompleted: item.type == TypeConstants.pack
                    ? completedPacks.contains(item.id)
                    : completed.contains(item.id),
              ),
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
