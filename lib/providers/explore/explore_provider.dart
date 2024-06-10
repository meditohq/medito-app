import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'explore_provider.g.dart';

@riverpod
Future<ExploreModel> explore(ref) async {
  final exploreRepository = ref.watch(exploreRepositoryProvider);
  final exploreQuery = ref.watch(exploreQueryProvider);

  return exploreQuery.hasExploreStarted
      ? exploreRepository.fetchExploreResult(exploreQuery.query)
      : ExploreModel();
}

final exploreQueryProvider = StateProvider<ExploreQueryModel>(
  (ref) => ExploreQueryModel(''),
);

//ignore: prefer-match-file-name
class ExploreQueryModel {
  final String query;
  final bool hasExploreStarted;

  ExploreQueryModel(this.query, {this.hasExploreStarted = false});
}
