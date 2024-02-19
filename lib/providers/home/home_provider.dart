import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_provider.g.dart';

@riverpod
Future<HomeModel> fetchHome(FetchHomeRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchHome();
}

@riverpod
Future<AnnouncementModel> fetchLatestAnnouncement(FetchLatestAnnouncementRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchLatestAnnouncement();
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
  ref.invalidate(remoteStatsProvider);
  await ref.read(remoteStatsProvider.future);
}
