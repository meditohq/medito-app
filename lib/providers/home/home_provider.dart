import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/stats/stats_model.dart';

part 'home_provider.g.dart';

@riverpod
Future<HomeModel> fetchHome(FetchHomeRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchHome();
}

@riverpod
Future<AnnouncementModel?> fetchLatestAnnouncement(
  FetchLatestAnnouncementRef ref,
) async {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return await homeRepository.fetchLatestAnnouncement();
}

@riverpod
Future<StatsModel> fetchStats(FetchStatsRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchStats();
}

@riverpod
Future<void> updateShortcutsIdsInPreference(
  UpdateShortcutsIdsInPreferenceRef ref, {
  required List<String> ids,
}) {
  final homeRepository = ref.watch(homeRepositoryProvider);

  return homeRepository.setShortcutIdsInPreference(ids);
}

@riverpod
Future<void> refreshHomeAPIs(RefreshHomeAPIsRef ref) async {
  ref.invalidate(fetchHomeProvider);
  await ref.read(fetchHomeProvider.future);
}