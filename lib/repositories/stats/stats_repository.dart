import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/stats/stats_model.dart';

part 'stats_repository.g.dart';

abstract class StatsRepository {
  Future<StatsModel> fetchStatsFromRemote();
}

class StatsRepositoryImpl extends StatsRepository {
  final DioApiService client;

  StatsRepositoryImpl({required this.client});

  @override
  Future<StatsModel> fetchStatsFromRemote() async {
    var response = await client.getRequest(HTTPConstants.STATS);

    return StatsModel.fromJson(response);
  }
}

@riverpod
StatsRepository statsRepository(StatsRepositoryRef _) {
  return StatsRepositoryImpl(client: DioApiService());
}
