import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'stats_repository.g.dart';

abstract class StatsRepository {
  Future<StatsModel> fetchStatsFromRemote();

  Future<TransferStatsModel?> fetchStatsFromPreference();

  Future<void> removeStatsFromPreference();
}

class StatsRepositoryImpl extends StatsRepository {
  final DioApiService client;

  StatsRepositoryImpl({required this.client});

  @override
  Future<StatsModel> fetchStatsFromRemote() async {
    var response = await client.getRequest(HTTPConstants.STATS);

    return StatsModel.fromJson(response);
  }

  @override
  Future<TransferStatsModel?> fetchStatsFromPreference() async {
    try {
      var pref = await SharedPreferences.getInstance();
      var keys = pref.getKeys();
      var listenedSessionIds = <int>[];
      keys.forEach((element) {
        if (element.startsWith(SharedPreferenceConstants.listened)) {
          listenedSessionIds.add(int.parse(
            element.replaceAll(SharedPreferenceConstants.listened, ''),
          ));
        }
      });
      if (listenedSessionIds.isNotEmpty) {
        String? currentStreak = await getCurrentStreak();
        String? minutesListened = await getMinutesListened();
        String? numSessions = await getNumTracks();
        String? longestStreak = await getLongestStreak();

        var statsModel = TransferStatsModel(
          currentStreak: int.parse(currentStreak),
          minutesListened: int.parse(minutesListened),
          listenedSessionsNum: int.parse(numSessions),
          longestStreak: int.parse(longestStreak),
          listenedSessionIds: listenedSessionIds,
        );

        return statsModel;
      }

      return null;
    } catch (err) {
      await Sentry.captureException(
        err,
        stackTrace: err.toString(),
      );
      rethrow;
    }
  }

  @override
  Future<void> removeStatsFromPreference() async {
    try {
      var pref = await SharedPreferences.getInstance();
      var keys = pref.getKeys();
      var listenedSessionIdKeys = [];
      keys.forEach((element) {
        if (element.startsWith(SharedPreferenceConstants.listened)) {
          listenedSessionIdKeys.add(element);
        }
      });
      for (var element in listenedSessionIdKeys) {
        await pref.remove(element);
      }
      await pref.remove(SharedPreferenceConstants.streakCount);
      await pref.remove(SharedPreferenceConstants.secsListened);
      await pref.remove(SharedPreferenceConstants.numSessions);
      await pref.remove(SharedPreferenceConstants.longestStreak);
    } catch (err) {
      await Sentry.captureException(
        err,
        stackTrace: err.toString(),
      );
      rethrow;
    }
  }
}

@riverpod
StatsRepository statsRepository(StatsRepositoryRef ref) {
  return StatsRepositoryImpl(client: ref.watch(dioClientProvider));
}
