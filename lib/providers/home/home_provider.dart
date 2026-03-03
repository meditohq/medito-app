import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/home/home_model.dart';
import '../../repositories/home/home_repository.dart';

part 'home_provider.g.dart';

@riverpod
Future<HomeModel> fetchHome(Ref ref) async {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  return await homeRepository.fetchHome();
}

@riverpod
Future<void> refreshHomeAPIs(Ref ref) async {
  ref.invalidate(fetchHomeProvider);
  await ref.read(fetchHomeProvider.future);
}
