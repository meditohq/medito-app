import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_provider.g.dart';

@riverpod
Future<StatsModel> remoteStats(RemoteStatsRef ref) {
  ref.keepAlive();

  return ref.watch(statsRepositoryProvider).fetchStatsFromRemote();
}
