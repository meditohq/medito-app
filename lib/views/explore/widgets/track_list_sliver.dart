import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/widgets/track_card_widget.dart';

/// Vertical list of track cards, as a sliver. Used for search results.
class TrackListSliver extends ConsumerWidget {
  const TrackListSliver({
    super.key,
    required this.tracks,
    this.onBeforeNavigate,
  });

  final List<TrackItem> tracks;

  /// Runs before a card navigates, e.g. to dismiss the keyboard.
  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(padding16, padding16, padding16, 0),
      sliver: SliverList.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final item = tracks[index];
          return Padding(
            key: ValueKey('track_${item.id}'),
            padding: const EdgeInsets.only(bottom: padding16),
            child: TrackCardWidget(
              title: item.title,
              subTitle: item.subtitle,
              coverUrlPath: item.coverUrl,
              onTap: () {
                onBeforeNavigate?.call();
                handleNavigation(
                  TypeConstants.track,
                  [item.id, item.path],
                  context,
                  ref: ref,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
