import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'stats_provider.g.dart';

@riverpod
Future<Map<String, dynamic>?> stats(ref) {
  return ref.watch(statsRepositoryProvider).fetchStatsFromPreference();
}
