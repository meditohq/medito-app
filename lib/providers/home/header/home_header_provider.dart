import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'home_header_provider.g.dart';

@riverpod
Future<HomeHeaderModel> fetchHomeHeader(FetchHomeHeaderRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return homeRepository.fetchHomeHeader();
}
