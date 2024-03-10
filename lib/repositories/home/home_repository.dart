import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/stats/stats_model.dart';

part 'home_repository.g.dart';

abstract class HomeRepository {
  Future<HomeModel> fetchHome();

  List<String> getLocalShortcutIds();

  Future<StatsModel> fetchStats();

  Future<AnnouncementModel> fetchLatestAnnouncement();

  ShortcutsModel getSortedShortcuts(
    ShortcutsModel shortcutsModel,
  );

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
  ShortcutsModel getSortedShortcuts(
    ShortcutsModel shortcutsModel,
  ) {
    //   var shortcutsIds = getLocalShortcutIds();
    //   var shortcutsCopy = [...shortcutsModel.shortcuts];
    //
    //   shortcutsCopy.sort((a, b) =>
    //       shortcutsIds.indexOf(a.id).compareTo(shortcutsIds.indexOf(b.id)));
    //
    //   return shortcutsModel.copyWith(shortcuts: shortcutsCopy);
    throw UnimplementedError();
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

  @override
  Future<AnnouncementModel> fetchLatestAnnouncement() {
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
