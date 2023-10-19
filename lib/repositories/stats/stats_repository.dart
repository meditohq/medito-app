import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Medito/models/models.dart';

part 'stats_repository.g.dart';

abstract class StatsRepository {
  Future<StatsModel> fetchStatsFromRemote();
  Future<Map<String, dynamic>?> fetchStatsFromPreference();
  Future<void> removeStatsFromPreference();
}

class StatsRepositoryImpl extends StatsRepository {
  final DioApiService client;

  StatsRepositoryImpl({required this.client});

  @override
  Future<StatsModel> fetchStatsFromRemote() async {
    try {
      var res = await client.getRequest(HTTPConstants.STATS);

      return StatsModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchStatsFromPreference() async {
    try {
      var pref = await SharedPreferences.getInstance();
      var keys = pref.getKeys();
      var listenedSessionIds = <int>[];
      keys.forEach((element) {
        if (element.startsWith('listened')) {
          listenedSessionIds.add(int.parse(element.replaceAll('listened', '')));
        }
      });
      if (listenedSessionIds.isNotEmpty) {
        String? currentStreak = await getCurrentStreak();
        String? minutesListened = await getMinutesListened();
        String? numSessions = await getNumTracks();
        String? longestStreak = await getLongestStreak();
        var data = {
          'currentStreak': int.parse(currentStreak),
          'minutesListened': int.parse(minutesListened),
          'listenedSessionsNum': int.parse(numSessions),
          'longestStreak': int.parse(longestStreak),
          'listenedSessionIds': listenedSessionIds,
        };
        print(data);

        return data;
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
        if (element.startsWith('listened')) {
          listenedSessionIdKeys.add(element);
        }
      });
      for (var element in listenedSessionIdKeys) {
        await pref.remove(element);
      }
      await pref.remove('streakCount');
      await pref.remove('secsListened');
      await pref.remove('numSessions');
      await pref.remove('longestStreak');
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
StatsRepository statsRepository(ref) {
  return StatsRepositoryImpl(client: ref.watch(dioClientProvider));
}
