import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BigPlayerWidget extends ConsumerWidget {
  const BigPlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyPlayingSession = ref.watch(playerProvider);

    if (currentlyPlayingSession != null) {
      return PlayerView(
        trackModel: currentlyPlayingSession,
        file: currentlyPlayingSession.audio.first.files.first,
      );
    }

    return SizedBox();
  }
}
