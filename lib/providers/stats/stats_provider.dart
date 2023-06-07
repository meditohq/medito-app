import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_provider.g.dart';

@riverpod
Future<StatsModel> remoteStats(ref) {
  ref.keepAlive();

  return ref.watch(statsRepositoryProvider).fetchStatsFromRemote();
}

@riverpod
Future<Map<String, dynamic>?> localStats(ref) {
  return ref.watch(statsRepositoryProvider).fetchStatsFromPreference();
}
