import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/home/home_model.dart';
import '../../repositories/home/home_repository.dart';

part 'home_provider.g.dart';

@riverpod
Future<HomeModel> fetchHome(Ref ref) async {
  final homeRepository = ref.watch(homeRepositoryProvider);
  ref.keepAlive();

  var homeModel = await homeRepository.fetchHome();
  var sortedShortcuts =
      await homeRepository.getSortedShortcuts(homeModel.shortcuts);

  return homeModel.copyWith(shortcuts: sortedShortcuts);
}

@riverpod
Future<void> updateShortcutsIdsInPreference(
  Ref ref, {
  required List<String> ids,
}) {
  final homeRepository = ref.watch(homeRepositoryProvider);

  return homeRepository.setShortcutIdsInPreference(ids);
}

@riverpod
Future<void> refreshHomeAPIs(Ref ref) async {
  ref.invalidate(fetchHomeProvider);
  await ref.read(fetchHomeProvider.future);
}
