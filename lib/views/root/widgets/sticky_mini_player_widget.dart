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
    var radius = BorderRadius.only(
      topRight: Radius.circular(currentlyPlayingSession != null ? 14 : 0),
      topLeft: Radius.circular(currentlyPlayingSession != null ? 14 : 0),
      bottomRight: Radius.circular(currentlyPlayingSession != null ? 20 : 0),
      bottomLeft: Radius.circular(currentlyPlayingSession != null ? 20 : 0),
    );    var opacity = ref.watch(pageviewNotifierProvider).scrollProportion;
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
      BorderRadius radius,
      double opacity,
      TrackModel currentlyPlayingSession,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: bottom,
      ),
      child: Material(
        elevation: 10.0,
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: 700),
            opacity: opacity,
            child: MiniPlayerWidget(
              trackModel: currentlyPlayingSession,
            ),
          ),
        ),
      ),
    );
  }



  void onDismiss(WidgetRef ref) {
    ref.read(playerProvider.notifier).removeCurrentlyPlayingTrackInPreference();
    ref.read(audioPlayerNotifierProvider).stop();
  }
}
