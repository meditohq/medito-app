import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'pack_provider.g.dart';

@riverpod
Future<PackModel> packs(
  ref, {
  required String packId,
}) {
  final packRepository = ref.watch(packRepositoryProvider);
  ref.keepAlive();

  return packRepository.fetchPacks(packId);
}
