import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/home/announcement/announcement_model.dart';
import '../shared_preference/shared_preference_provider.dart';
import '../../repositories/home/home_repository.dart';

part 'announcement_provider.g.dart';

const _dismissedAnnouncementKey = 'dismissed_announcement_id';

@riverpod
Future<List<String>> getDismissedAnnouncementIds(Ref ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final ids = prefs.getStringList(_dismissedAnnouncementKey) ?? [];

  return ids;
}

class DismissedAnnouncement extends Notifier<void> {
  @override
  void build() {}

  Future<void> dismissAnnouncement(String id) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final ids = prefs.getStringList(_dismissedAnnouncementKey) ?? [];

    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList(_dismissedAnnouncementKey, ids);
    }

    ref.invalidate(getDismissedAnnouncementIdsProvider);
  }
}

final dismissedAnnouncementProvider =
    NotifierProvider<DismissedAnnouncement, void>(() {
      return DismissedAnnouncement();
    });

@riverpod
Future<AnnouncementModel?> fetchLatestAnnouncement(Ref ref) async {
  final homeRepository = ref.watch(homeRepositoryProvider);
  final List<String> dismissedIds = await ref.watch(
    getDismissedAnnouncementIdsProvider.future,
  );
  ref.keepAlive();

  final announcement = await homeRepository.fetchLatestAnnouncement();

  if (announcement != null && dismissedIds.contains(announcement.id)) {
    return null;
  }

  return announcement;
}
