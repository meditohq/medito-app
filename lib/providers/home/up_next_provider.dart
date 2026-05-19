import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/home_widget_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'up_next_provider.g.dart';

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

  const UpNextData({
    required this.pack,
    required this.nextSession,
    required this.completedCount,
    required this.totalCount,
  });

  double get progressPercentage =>
      totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

  bool get isCompleted => completedCount >= totalCount;
}

/// Derives the home-screen "up next" surface from [packProvider], which
/// already merges per-item completion against [statsProvider]. Watching it
/// means up-next reacts automatically when a track completes — no manual
/// invalidation needed at the play sites.
///
/// When the pinned non-default pack finishes, we clear the pin so the
/// default pack takes over on the next derivation cycle.
@Riverpod(keepAlive: true)
AsyncValue<UpNextData> upNext(Ref ref) {
  final packId = ref.watch(upNextPackIdProvider);
  final packAsync = ref.watch(packProvider(packId: packId));

  return packAsync.whenData((pack) {
    final completedCount =
        pack.items.where((item) => item.isCompleted == true).length;
    final isCompleted = completedCount >= pack.items.length;
    final isDefaultPack = packId == ConfigConstants.basicsPackId;

    // A non-default pack just got fully completed — drop the pin so the
    // basics pack takes over. Deferred to a microtask because we're inside
    // a provider derivation; the invalidate triggers an upNext rebuild.
    if (isCompleted && !isDefaultPack) {
      Future.microtask(() async {
        await ref
            .read(sharedPreferencesProvider)
            .remove(SharedPreferenceConstants.upNextPackId);
        ref.invalidate(upNextPackIdProvider);
      });
    }

    final nextSession = isCompleted
        ? null
        : pack.items.firstWhere(
            (item) => item.isCompleted != true,
            orElse: () => pack.items.first,
          );

    if (nextSession != null) {
      HomeWidgetService.updateUpNextWidget(
        title: nextSession.title,
        packTitle: pack.title,
        trackId: nextSession.id,
        subtitle: nextSession.subtitle,
        completed: completedCount,
        total: pack.items.length,
      ).ignore();
    }

    return UpNextData(
      pack: pack,
      nextSession: nextSession,
      completedCount: completedCount,
      totalCount: pack.items.length,
    );
  });
}
