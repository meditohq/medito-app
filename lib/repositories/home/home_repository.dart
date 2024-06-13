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
