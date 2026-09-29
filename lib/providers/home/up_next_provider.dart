import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/pack_sequence.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/home_widget_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'up_next_provider.g.dart';

// De-duplicates widget pushes — the provider re-derives on every stats refresh
// even when the surfaced session hasn't actually changed.
String? _lastPushedWidgetSignature;

/// The pack the home screen treats as the user's current "up next" course.
/// Persisted under [SharedPreferenceConstants.upNextPackId]; null falls back
/// to the configured basics pack.
@riverpod
String upNextPackId(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(SharedPreferenceConstants.upNextPackId) ??
      ConfigConstants.basicsPackId;
}

class UpNextData {
  final PackModel pack;
  final PackItemsModel? nextSession;
  final int completedCount;
  final int totalCount;

  /// First remaining pack with unfinished sessions; null at the end of the path.
  final String? nextPackId;

  final bool isEndOfPath;

  const UpNextData({
    required this.pack,
    required this.nextSession,
    required this.completedCount,
    required this.totalCount,
    this.nextPackId,
    this.isEndOfPath = false,
  });

  double get progressPercentage =>
      totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

  /// `totalCount > 0` stops an unloaded pack satisfying `0 >= 0`.
  bool get isCompleted => totalCount > 0 && completedCount >= totalCount;
}

/// Derives the home-screen "up next" surface from [packProvider], which
/// already merges per-item completion against [statsProvider]. Watching it
/// means up-next reacts automatically when a track completes — no manual
/// invalidation needed at the play sites.
///
/// When the pinned pack finishes the widget renders a completed state; the pin
/// is not cleared behind the user's back.
@Riverpod(keepAlive: true)
AsyncValue<UpNextData> upNext(Ref ref) {
  final packId = ref.watch(upNextPackIdProvider);
  final packAsync = ref.watch(packProvider(packId: packId));

  return packAsync.when(
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
    data: (pack) {
      final completedCount = pack.items
          .where((item) => item.isCompleted == true)
          .length;
      final isCompleted =
          pack.items.isNotEmpty && completedCount >= pack.items.length;

      // isEmpty must short-circuit: the orElse reads `first` and would throw.
      final nextSession = (isCompleted || pack.items.isEmpty)
          ? null
          : pack.items.firstWhere(
              (item) => item.isCompleted != true,
              orElse: () => pack.items.first,
            );

      final signature = nextSession != null
          ? '${nextSession.id}|${pack.title}|$completedCount/${pack.items.length}'
          : '|${pack.title}|$completedCount/${pack.items.length}';

      if (signature != _lastPushedWidgetSignature) {
        _lastPushedWidgetSignature = signature;
        if (nextSession != null) {
          HomeWidgetService.updateUpNextWidget(
            title: nextSession.title,
            packTitle: pack.title,
            trackId: nextSession.id,
            subtitle: nextSession.subtitle,
            completed: completedCount,
            total: pack.items.length,
          ).ignore();
        } else {
          // Pack finished — clear the widget so it stops showing a stale track.
          // Tapping the empty-state widget just opens the app.
          HomeWidgetService.updateUpNextWidget(
            title: '',
            packTitle: '',
            trackId: '',
            subtitle: '',
            completed: completedCount,
            total: pack.items.length,
          ).ignore();
        }
      }

      // Resolve the CTA before offering it: users may already have completed
      // several later packs (including via the legacy megapack).
      final nextPack = isCompleted
          ? _nextUnfinishedPack(ref, PackSequence.nextPackAfter(packId))
          : const AsyncData<String?>(null);
      return nextPack.whenData(
        (nextPackId) => UpNextData(
          pack: pack,
          nextSession: nextSession,
          completedCount: completedCount,
          totalCount: pack.items.length,
          nextPackId: nextPackId,
          isEndOfPath:
              isCompleted &&
              nextPackId == null &&
              (PackSequence.contains(packId) ||
                  PackSequence.isPathTerminal(packId)),
        ),
      );
    },
  );
}

/// Watch each candidate so completion changes also update the offered pack.
/// Loading/errors must propagate: an unknown pack is not a completed pack.
AsyncValue<String?> _nextUnfinishedPack(Ref ref, String? packId) {
  if (packId == null) return const AsyncData(null);

  return ref
      .watch(packProvider(packId: packId))
      .when(
        loading: () => const AsyncLoading(),
        error: (error, stack) => AsyncError(error, stack),
        data: (pack) {
          if (pack.items.any((item) => item.isCompleted != true)) {
            return AsyncData(packId);
          }
          return _nextUnfinishedPack(ref, PackSequence.nextPackAfter(packId));
        },
      );
}
