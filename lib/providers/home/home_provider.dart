import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/home/announcement/announcement_model.dart';
import '../../models/home/home_model.dart';
import '../../repositories/home/home_repository.dart';

part 'home_provider.g.dart';

const noneAnnouncementId = 'none';

@riverpod
Future<HomeModel> fetchHome(FetchHomeRef ref) async {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  var homeModel = await homeRepository.fetchHome();
  var sortedShortcuts =
      await homeRepository.getSortedShortcuts(homeModel.shortcuts);

  return homeModel.copyWith(shortcuts: sortedShortcuts);
}

@riverpod 
Future<AnnouncementModel?> fetchLatestAnnouncement(
  FetchLatestAnnouncementRef ref,
) async {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  var announcement = await homeRepository.fetchLatestAnnouncement();

  return announcement?.id == noneAnnouncementId ? null : announcement;
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
