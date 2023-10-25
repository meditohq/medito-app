import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomPaddingWidget extends ConsumerWidget {
  const BottomPaddingWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyPlayingSession = ref.watch(playerProvider);

    return SizedBox(
      height: currentlyPlayingSession != null
          ? getBottomPaddingWithStickyMiniPlayer(
              context,
            )
          : getBottomPadding(context),
    );
  }
}
