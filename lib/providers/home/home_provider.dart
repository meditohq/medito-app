import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'home_provider.g.dart';

@riverpod
Future<HomeModel> home(HomeRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchHomeData();
}

@riverpod
Future<HomeHeaderModel> fetchHomeHeader(FetchHomeHeaderRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchHomeHeader();
}

@riverpod
Future<ShortcutsModel> fetchShortcuts(FetchShortcutsRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchShortcuts();
}

@riverpod
Future<QuoteModel> fetchQuote(FetchQuoteRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchQuote();
}
