import 'package:medito/providers/events/events_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../models/track/track_model.dart';
import '../../repositories/track/track_repository.dart';
import '../shared_preference/shared_preference_provider.dart';

part 'track_provider.g.dart';

@riverpod
class GuideNamePreference extends _$GuideNamePreference {
  @override
  String? build({required String trackId}) {
    var prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(SharedPreferenceConstants.lastSelectedGuideName);
  }

  void setGuideName(String? guideName) {
    var prefs = ref.read(sharedPreferencesProvider);
    if (guideName != null) {
      prefs.setString(
          SharedPreferenceConstants.lastSelectedGuideName, guideName);
    } else {
      prefs.remove(SharedPreferenceConstants.lastSelectedGuideName);
    }
    state = guideName;
  }
}

@riverpod
class Tracks extends _$Tracks {
  @override
  Future<TrackModel> build({required String trackId}) async {
    final trackRepository = ref.watch(trackRepositoryProvider);
    final track = await trackRepository.fetchTrack(trackId);
    return track;
  }

  Future<void> toggleFavorite(bool newLikedState) async {
    state = await AsyncValue.guard(() async {
      final currentTrack = state.value!;
      final updatedTrack = currentTrack.copyWith(isLiked: newLikedState);

      if (newLikedState) {
        await ref.read(
            markAsFavouriteEventProvider(trackId: currentTrack.id).future);
      } else {
        await ref.read(
            markAsNotFavouriteEventProvider(trackId: currentTrack.id).future);
      }

      ref.invalidate(packProvider);

      return updatedTrack;
    });
  }
}

@riverpod
class FavoriteStatus extends _$FavoriteStatus {
  @override
  bool build({required String trackId}) {
    final trackState = ref.watch(tracksProvider(trackId: trackId));
    return trackState.value?.isLiked ?? false;
  }

  void toggle() {
    state = !state;
    ref.read(tracksProvider(trackId: trackId).notifier).toggleFavorite(state);
  }
}
