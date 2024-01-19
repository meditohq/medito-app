import 'package:Medito/constants/constants.dart';
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

  Future<void> markComplete({
    required String audioFileId,
    required String trackId,
  }) async {
    var packs = state.value;
    var prevState = state.value;
    try {
      if (packs != null) {
        var selectedItemIndex =
            packs.items.indexWhere((element) => element.id == audioFileId);
        packs.items[selectedItemIndex] =
            packs.items[selectedItemIndex].copyWith(isCompleted: true);
        var audio = AudioCompletedModel(
          audioFileId: audioFileId,
          trackId: trackId,
          updateStats: false,
        );
        var event = EventsModel(
          name: EventTypes.audioCompleted,
          payload: audio.toJson(),
        );

        state = AsyncData(packs);
        await ref.read(eventsProvider(event: event.toJson()).future);
      }
    } catch (err) {
      if (prevState != null) state = AsyncData(prevState);
    }
  }
}
