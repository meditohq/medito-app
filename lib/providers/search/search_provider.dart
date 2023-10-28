import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'search_provider.g.dart';

@riverpod
Future<SearchModel> search(ref) async {
  final searchRepository = ref.watch(searchRepositoryProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return searchQuery.search
      ? searchRepository.fetchSearchResult(searchQuery.query)
      : SearchModel();
}

final searchQueryProvider = StateProvider<SearchQueryModel>(
  (ref) => SearchQueryModel(''),
);

//ignore: prefer-match-file-name
class SearchQueryModel {
  final String query;
  final bool search;

  SearchQueryModel(this.query, {this.search = false});
}
