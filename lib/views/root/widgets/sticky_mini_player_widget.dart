import 'package:Medito/models/track/track_model.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/player/widgets/mini_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StickyMiniPlayerWidget extends ConsumerWidget {
  const StickyMiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyPlayingSession = ref.watch(playerProvider);
    final audioPlayerProvider = ref.watch(audioPlayerNotifierProvider);
    var radius = Radius.circular(currentlyPlayingSession != null ? 15 : 0);
    var opacity = ref.watch(pageviewNotifierProvider).scrollProportion;
    var bottom = getBottomPadding(context) + 8;

    if (currentlyPlayingSession != null) {
      return StreamBuilder<bool>(
        stream: audioPlayerProvider.playbackState
            .map((state) => state.playing)
            .distinct(),
        builder: (context, snapshot) {
          final playing = snapshot.data ?? false;
          if (playing) {
            return _miniPlayer(
              bottom,
              radius,
              opacity,
              currentlyPlayingSession,
            );
          }

          return Dismissible(
            key: UniqueKey(),
            onDismissed: (_) => onDismiss(ref),
            child:
                _miniPlayer(bottom, radius, opacity, currentlyPlayingSession),
          );
        },
      );
    }

    return SizedBox();
  }

  Padding _miniPlayer(
    double bottom,
    Radius radius,
    double opacity,
    TrackModel currentlyPlayingSession,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(radius),
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 700),
          opacity: opacity,
          child: MiniPlayerWidget(
            trackModel: currentlyPlayingSession,
          ),
        ),
      ),
    );
  }

  void onDismiss(WidgetRef ref) {
    ref.read(playerProvider.notifier).removeCurrentlyPlayingTrackInPreference();
  }
}
