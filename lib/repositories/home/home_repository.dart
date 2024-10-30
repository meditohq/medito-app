import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_repository.g.dart';

abstract class HomeRepository {
  Future<HomeModel> fetchHome();

  List<String> getLocalShortcutIds();

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
  Future<HomeModel> fetchHome() async {
    var response = await client.getRequest(HTTPConstants.home);

    return HomeModel.fromJson(response);
  }

  @override
  Future<AnnouncementModel?> fetchLatestAnnouncement() async {
    var response = await client.getRequest(HTTPConstants.latestAnnouncement);

    return AnnouncementModel.fromJson(response);
  }

  Future<List<ShortcutsModel>> getSortedShortcuts(
      List<ShortcutsModel> shortcuts) async {
    var savedIds = getLocalShortcutIds();
    if (savedIds.isEmpty) return shortcuts;

    var sortedShortcuts = List<ShortcutsModel>.from(shortcuts);
    sortedShortcuts.sort((a, b) {
      var indexA = savedIds.indexOf(a.id ?? '');
      var indexB = savedIds.indexOf(b.id ?? '');
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;

      return indexA.compareTo(indexB);
    });

    return sortedShortcuts;
  }
}

@riverpod
HomeRepositoryImpl homeRepository(Ref ref) {
  return HomeRepositoryImpl(ref: ref, client: DioApiService());
}
