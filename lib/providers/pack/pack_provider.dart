import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pack_provider.g.dart';

@riverpod
Future<List<PackItemsModel>> fetchAllPacks(FetchAllPacksRef ref) {
  var packRepository = ref.watch(packRepositoryProvider);
  ref.keepAlive();

  return packRepository.fetchAllPacks();
}

@riverpod
//ignore: prefer-match-file-name
class Pack extends _$Pack {
  @override
  AsyncValue<PackModel> build({required String packId}) {
    fetchPacks(packId: packId);

    return AsyncLoading();
  }

  Future<void> fetchPacks({required String packId}) async {
    final packRepository = ref.read(packRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => await packRepository.fetchPacks(packId),
    );
    ref.keepAlive();
  }

  Future<void> toggleIsComplete({
    required String audioFileId,
    required String trackId,
    required bool isComplete,
  }) async {
    var packs = state.value;
    var prevState = state.value;
    try {
      if (packs != null) {
        var selectedItemIndex =
            packs.items.indexWhere((element) => element.id == audioFileId);
        packs.items[selectedItemIndex] =
            packs.items[selectedItemIndex].copyWith(isCompleted: !isComplete);

        state = AsyncData(packs);
        if (isComplete) {
          await ref.read(markAsNotListenedEventProvider(id: trackId).future);
        } else {
          await ref.read(markAsListenedEventProvider(id: trackId).future);
        }
      }
    } catch (err) {
      if (prevState != null) state = AsyncData(prevState);
    }
  }
}
