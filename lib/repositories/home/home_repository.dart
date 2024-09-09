import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/stats/stats_model.dart';

part 'home_repository.g.dart';

abstract class HomeRepository {
  Future<HomeModel> fetchHome();

  List<String> getLocalShortcutIds();

  Future<StatsModel> fetchStats();

  Future<AnnouncementModel?> fetchLatestAnnouncement();

  Future<void> setShortcutIdsInPreference(
    List<String> ids,
  );
}

class HomeRepositoryImpl extends HomeRepository {
  final DioApiService client;
  final Ref ref;

  HomeRepositoryImpl({required this.ref, required this.client});

  @override
  List<String> getLocalShortcutIds() {
    return ref
            .read(sharedPreferencesProvider)
            .getStringList(SharedPreferenceConstants.shortcuts) ??
        [];
  }

  @override
  Future<void> setShortcutIdsInPreference(List<String> ids) async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(SharedPreferenceConstants.shortcuts, ids);
  }

  @override
  Future<HomeModel> fetchHome() {
    return client.getRequest(HTTPConstants.HOME).then((response) {
      return HomeModel.fromJson(response);
    });
  }

  @override
  Future<StatsModel> fetchStats() {
    return client.getRequest(HTTPConstants.STATS).then((response) {
      return StatsModel.fromJson(response);
    });
  }

  Future<List<ShortcutsModel>> getSortedShortcuts(List<ShortcutsModel> shortcuts) async {
    var savedIds = getLocalShortcutIds();
    if (savedIds.isEmpty) return shortcuts;

    var sortedShortcuts = List<ShortcutsModel>.from(shortcuts);
    sortedShortcuts.sort((a, b) {
      var indexA = savedIds.indexOf(a.id);
      var indexB = savedIds.indexOf(b.id);
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;

      return indexA.compareTo(indexB);
    });

    return sortedShortcuts;
  }

  @override
  Future<AnnouncementModel?> fetchLatestAnnouncement() {
    return client
        .getRequest(HTTPConstants.LATEST_ANNOUNCEMENT)
        .then((response) {
      return AnnouncementModel.fromJson(response);
    });
  }
}

@riverpod
HomeRepositoryImpl homeRepository(HomeRepositoryRef ref) {
  return HomeRepositoryImpl(ref: ref, client: DioApiService());
}
