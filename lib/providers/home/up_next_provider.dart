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

  /// The pack to pin when the user accepts the completed-state CTA, resolved
  /// from [PackSequence]. Null when the finished pack is the last in the path
  /// or was never part of it — the card then renders the end-of-path variant.
  final String? nextPackId;

  /// True when the user has just finished the final pack in [PackSequence], as
  /// opposed to finishing something outside the curated path. Both cases have a
  /// null [nextPackId] but they are different product moments.
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

  /// Guards against an empty item list reading as "completed" — an unloaded or
  /// misconfigured pack would otherwise satisfy `0 >= 0` and render a bogus
  /// completion card.
  bool get isCompleted => totalCount > 0 && completedCount >= totalCount;
}

/// Derives the home-screen "up next" surface from [packProvider], which
/// already merges per-item completion against [statsProvider]. Watching it
/// means up-next reacts automatically when a track completes — no manual
/// invalidation needed at the play sites.
///
/// When the pinned pack finishes, [UpNextData.nextSession] is null and
/// [UpNextData.isCompleted] is true — the widget renders a completed state
/// rather than the pin being cleared behind the user's back.
@Riverpod(keepAlive: true)
AsyncValue<UpNextData> upNext(Ref ref) {
  final packId = ref.watch(upNextPackIdProvider);
  final packAsync = ref.watch(packProvider(packId: packId));

  return packAsync.whenData((pack) {
    final completedCount = pack.items
        .where((item) => item.isCompleted == true)
        .length;
    // `totalCount > 0` matters: an empty item list would otherwise satisfy
    // `0 >= 0` and present an unloaded pack as finished.
    final isCompleted =
        pack.items.isNotEmpty && completedCount >= pack.items.length;

    // The pin is deliberately NOT cleared here. It used to be, via a
    // Future.microtask inside this derivation, which caused two problems:
    // finishing a pack silently reverted Up Next to the beginner Basics pack
    // (or hid the card entirely when Basics was also done), and pinning an
    // already-completed pack from the pack view unpinned itself immediately
    // while still showing a success snackbar. Completion is now a rendered
    // state that the user moves on from explicitly — see UpNextWidget.

    // `pack.items.isEmpty` must short-circuit before the orElse below, which
    // reads `pack.items.first` and would throw on an empty list. Previously an
    // empty pack was masked by `0 >= 0` marking it completed; now that empty
    // and completed are distinguished, the emptiness has to be handled here.
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

    return UpNextData(
      pack: pack,
      nextSession: nextSession,
      completedCount: completedCount,
      totalCount: pack.items.length,
      nextPackId: isCompleted ? PackSequence.nextPackAfter(packId) : null,
      // Terminal covers both the last pack on the path and the legacy megapack,
      // which contains the same eleven packs' worth of content — finishing
      // either means there is no more course material to offer.
      isEndOfPath: isCompleted && PackSequence.isPathTerminal(packId),
    );
  });
}
