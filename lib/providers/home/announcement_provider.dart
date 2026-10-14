import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/home/announcement/announcement_model.dart';
import '../../services/history/app_history_service.dart';
import '../shared_preference/shared_preference_provider.dart';
import '../../repositories/home/home_repository.dart';

part 'announcement_provider.g.dart';

const _dismissedAnnouncementKey = 'dismissed_announcement_id';

// TEMPORARY: iOS new installs don't see the announcement until this long
// after first open.
const _iosNewInstallAnnouncementDelay = Duration(hours: 6);

/// True on iOS within [_iosNewInstallAnnouncementDelay] of first open. First
/// open is the earliest version-history entry (recorded since 26.4.24), so
/// upgrades from older builds are hidden for at most the same window.
bool _isIosNewInstall(SharedPreferences prefs) {
  if (!Platform.isIOS) return false;
  final history = AppHistoryService.getVersionHistory(prefs);
  final firstOpen = history
      .map((e) => DateTime.tryParse(e['firstSeenAt'] as String? ?? ''))
      .whereType<DateTime>()
      .fold<DateTime?>(
        null,
        (earliest, t) =>
            earliest == null || t.isBefore(earliest) ? t : earliest,
      );
  if (firstOpen == null) return false;
  return DateTime.now().difference(firstOpen) < _iosNewInstallAnnouncementDelay;
}

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

  if (_isIosNewInstall(ref.read(sharedPreferencesProvider))) return null;

  final announcement = await homeRepository.fetchLatestAnnouncement();

  if (announcement != null && dismissedIds.contains(announcement.id)) {
    return null;
  }

  return announcement;
}
