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
  Future<void> removeStatsFromPreference();
  Future<void> addDummyStats();
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
      // await addDummyStats();
      var keys = pref.getKeys();
      List<int> listenedSessionIds = [];
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
          'listendedSessionsNum': int.parse(numSessions),
          'longestStreak': int.parse(longestStreak),
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
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addDummyStats() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var ids = [
      390,
      9,
      20,
      9,
      2,
      87,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      41,
      42,
      43,
      44,
      45,
      46,
      47,
      48,
      49,
      50,
      51,
      52,
      53,
      54,
      55,
      56,
      57,
      58,
      59,
      60,
      61,
      62,
      63,
      64,
      65,
      66,
      67,
      68,
      69,
      70,
      71,
      72,
      73,
      74,
      75,
      76,
      77,
      78,
      79,
      80,
      81,
      82,
      83,
      84,
      85,
      86,
      87,
      88,
      89,
      90,
      91,
      92,
      93,
      94,
      95,
      96,
      97,
      98,
      99,
      100,
      101,
      102,
      103,
      104,
      105,
      106,
      107,
      108,
      109,
      110,
      111,
      112,
      113,
      114,
      115,
      116,
      117,
      118,
      119,
      120,
      121,
      122,
      123,
      124,
      125,
      126,
      127,
      128,
      129,
      130,
      131,
      132,
      133,
      134,
      135,
      136,
      137,
      138,
      139,
      140,
    ];
    for (var id in ids) {
      await sharedPreferences.setBool('listened$id', true);
    }
    await sharedPreferences.setInt('longestStreak', 17);
    await sharedPreferences.setInt('listendedSessionsNum', 763);
    await sharedPreferences.setInt('minutesListened', 70);
    await sharedPreferences.setInt('currentStreak', 18);
  }
}

@riverpod
StatsRepository statsRepository(ref) {
  return StatsRepositoryImpl(client: ref.watch(dioClientProvider));
}
