import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Medito/models/models.dart';

part 'stats_repository.g.dart';

abstract class StatsRepository {
  Future<StatsModel> fetchStatsFromRemote();
  Future<Map<String, dynamic>?> fetchStatsFromPreference();
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
      var listenedSessionIds = [];
      keys.forEach((element) {
        if (element.startsWith('listened')) {
          listenedSessionIds.add(element.replaceAll('listened', ''));
        }
      });
      if (listenedSessionIds.isNotEmpty) {
        String? currentStreak = await getCurrentStreak();
        String? minutesListened = await getMinutesListened();
        String? numSessions = await getNumMeditations();
        String? longestStreak = await getLongestStreak();
        var data = {
          'currentStreak': currentStreak,
          'minutesListened': minutesListened,
          'listendedSessionsNum': numSessions,
          'longestStreak': longestStreak,
          'listenedSessionIds': listenedSessionIds,
        };
        print(data);

        return data;
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
StatsRepository statsRepository(ref) {
  return StatsRepositoryImpl(client: ref.watch(dioClientProvider));
}
