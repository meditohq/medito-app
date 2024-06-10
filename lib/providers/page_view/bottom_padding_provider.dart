import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bottomPaddingProvider = StateProvider.family<double, BuildContext>(
  (ref, context) {
    final currentlyPlayingSession = ref.watch(playerProvider);
    var height = currentlyPlayingSession != null
        ? getBottomPaddingWithStickyMiniPlayer(
            context,
          )
        : getBottomPadding(context);

    return height;
  },
);
