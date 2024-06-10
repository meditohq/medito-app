import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'me_provider.g.dart';

@riverpod
Future<MeModel> me(MeRef ref) {
  ref.keepAlive();

  return ref.watch(meRepositoryProvider).fetchMe();
}
