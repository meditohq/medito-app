import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/player/player_provider.dart';

class NextTrackNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> preloadNextTrack(String trackId) async {
    state = const AsyncValue.loading();
    try {
      final track = await ref.read(tracksProvider(trackId: trackId).future);
      final selectedAudio = _selectBestAudioMatch(
        track.audio,
        guideName: ref.read(guideNamePreferenceProvider).value,
        preferredDuration: ref.read(durationPreferenceProvider),
      );

      if (selectedAudio != null) {
        ref.read(playerProvider.notifier).cacheTrackData(
              track: track,
              file: selectedAudio.files.first,
            );
      }
      state = AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  TrackAudioModel? _selectBestAudioMatch(
    List<TrackAudioModel> audioList, {
    String? guideName,
    int? preferredDuration,
  }) {
    if (audioList.isEmpty) return null;

    List<TrackAudioModel> filtered = guideName != null
        ? audioList.where((a) => a.guideName == guideName).toList()
        : audioList;

    if (filtered.isEmpty) filtered = audioList;

    TrackAudioModel? closest;
    int? closestDiff;

    for (final audio in filtered) {
      final duration = audio.files.first.duration;
      final diff = (preferredDuration ?? duration) - duration;

      if (closest == null || diff.abs() < closestDiff!) {
        closest = audio;
        closestDiff = diff.abs();
      }
    }

    return closest ?? audioList.first;
  }
}

final nextTrackProvider = AsyncNotifierProvider<NextTrackNotifier, void>(
  NextTrackNotifier.new,
); 