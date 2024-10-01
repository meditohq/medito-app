import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/assign_dio_headers.dart';
import 'package:medito/services/network/dio_api_service.dart';
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
  Future<void>? _refreshFuture;

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

  Future<T> _executeWithTokenRefresh<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } on UnauthorizedException catch (_) {
      await _refreshUserToken();
      return await apiCall();
    } on DioException {
      rethrow;
    }
  }

  Future<void> _refreshUserToken() async {
    _refreshFuture ??= _performTokenRefresh();
    await _refreshFuture;
  }

  Future<void> _performTokenRefresh() async {
    try {
      var user = await ref.read(authRepositoryProvider).generateUserToken();
      var token = user.token;

      if (token != null) {
        var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
        AssignDioHeaders(token, deviceInfo).assign();
      }
    } finally {
      _refreshFuture = null;
    }
  }

  @override
  Future<HomeModel> fetchHome() async {
    return _executeWithTokenRefresh(() async {
      var response = await client.getRequest(HTTPConstants.home);
      return HomeModel.fromJson(response);
    });
  }

  @override
  Future<StatsModel> fetchStats() async {
    return _executeWithTokenRefresh(() async {
      var response = await client.getRequest(HTTPConstants.stats);
      return StatsModel.fromJson(response);
    });
  }

  @override
  Future<AnnouncementModel?> fetchLatestAnnouncement() async {
    return _executeWithTokenRefresh(() async {
      var response = await client.getRequest(HTTPConstants.latestAnnouncement);
      return AnnouncementModel.fromJson(response);
    });
  }

  Future<List<ShortcutsModel>> getSortedShortcuts(
      List<ShortcutsModel> shortcuts) async {
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
}

@riverpod
HomeRepositoryImpl homeRepository(HomeRepositoryRef ref) {
  return HomeRepositoryImpl(ref: ref, client: DioApiService());
}
