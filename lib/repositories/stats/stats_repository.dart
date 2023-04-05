import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'stats_repository.g.dart';

abstract class StatsRepository {
  Future<Map<String, dynamic>?> fetchStatsFromPreference();
}

class StatsRepositoryImpl extends StatsRepository {
  final DioApiService client;

  StatsRepositoryImpl({required this.client});

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
        String? numSessions = await getNumSessions();
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
