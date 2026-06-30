import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/utils/track_variant_selector.dart';

class NextTrackNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> preloadNextTrack(String trackId) async {
    state = const AsyncValue.loading();
    try {
      final track = await ref.read(tracksProvider(trackId: trackId).future);
      final selection = TrackVariantSelector.resolve(
        track,
        guideName: ref.read(guideNamePreferenceProvider),
        durationMs: ref.read(durationPreferenceProvider),
      );
      ref
          .read(playerProvider.notifier)
          .prepare(
            PlaybackRequest.fromTrack(track, selection.voice, selection.file),
          );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final nextTrackProvider = AsyncNotifierProvider<NextTrackNotifier, void>(
  NextTrackNotifier.new,
);
