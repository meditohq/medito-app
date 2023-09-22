import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'search_provider.g.dart';

@riverpod
Future<SearchModel> search(ref) async {
  var query = ref.watch(searchQueryProvider);
  final searchRepository = ref.watch(searchRepositoryProvider);

  return query != ''
      ? searchRepository.fetchSearchResult(query)
      : SearchModel();
}

final searchQueryProvider = StateProvider((ref) => '');
