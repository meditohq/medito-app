import 'dart:convert';

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

/// What made a pack complete when the user saw it: the ids of its direct
/// track items and of its direct sub-pack items.
class LocalPackCompletion {
  const LocalPackCompletion({required this.tracks, required this.packs});

  final Set<String> tracks;
  final Set<String> packs;

  bool get isEmpty => tracks.isEmpty && packs.isEmpty;

  bool sameAs(LocalPackCompletion other) =>
      tracks.length == other.tracks.length &&
      packs.length == other.packs.length &&
      tracks.containsAll(other.tracks) &&
      packs.containsAll(other.packs);

  Map<String, dynamic> toJson() => {
    'tracks': tracks.toList(),
    'packs': packs.toList(),
  };
}

/// Packs the user has seen fully complete on their own device, keyed by pack
/// id. Backs up [completedPackIds] when the server's track lists are missing
/// or don't match what the pack screen shows. Completion is per account, so
/// an entry only counts while its recorded tracks and sub-packs are still
/// complete in the current stats (see [completedPackIds]).
@Riverpod(keepAlive: true)
class LocallyCompletedPacks extends _$LocallyCompletedPacks {
  @override
  Map<String, LocalPackCompletion> build() {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.locallyCompletedPacks);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: LocalPackCompletion(
            tracks: Set<String>.from(
              (entry.value as Map<String, dynamic>)['tracks'] as List,
            ),
            packs: Set<String>.from(
              (entry.value as Map<String, dynamic>)['packs'] as List,
            ),
          ),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Records [pack] as complete (with the track and sub-pack ids it was
  /// complete with) or removes its record. No-op when the stored entry is
  /// already equal, so listeners that call this on every pack update can't
  /// cause a rebuild loop.
  void setComplete(PackModel pack, bool complete) {
    final current = state[pack.id];
    final Map<String, LocalPackCompletion> next;
    if (complete) {
      final entry = LocalPackCompletion(
        tracks: {
          for (final i in pack.items)
            if (i.type == TypeConstants.track) i.id,
        },
        packs: {
          for (final i in pack.items)
            if (i.type == TypeConstants.pack) i.id,
        },
      );
      if (current != null && current.sameAs(entry)) return;
      next = {...state, pack.id: entry};
    } else {
      if (current == null) return;
      next = {...state}..remove(pack.id);
    }
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          SharedPreferenceConstants.locallyCompletedPacks,
          jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
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
///
/// A local record only counts while every track it was recorded with is still
/// in the current stats and every recorded sub-pack is itself complete, so
/// records left by another account (or cleared stats) are ignored.
@Riverpod(keepAlive: true)
Set<String> completedPackIds(Ref ref) {
  final local = ref.watch(locallyCompletedPacksProvider);
  final packTracks = ref.watch(packTrackIdsProvider).value ?? const {};
  final checked = ref.watch(statsProvider).value?.tracksChecked;
  final completed = checked?.toSet() ?? <String>{};

  final server = <String>{
    if (completed.isNotEmpty)
      for (final entry in packTracks.entries)
        if (entry.value.isNotEmpty && entry.value.every(completed.contains))
          entry.key,
  };

  bool isValid(String id, Set<String> visiting) {
    if (server.contains(id)) return true;
    final entry = local[id];
    if (entry == null || entry.isEmpty) return false;
    if (!visiting.add(id)) return false;
    final ok =
        entry.tracks.every(completed.contains) &&
        entry.packs.every((p) => isValid(p, visiting));
    visiting.remove(id);
    return ok;
  }

  return {
    ...server,
    for (final id in local.keys)
      if (isValid(id, <String>{})) id,
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
