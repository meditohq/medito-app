import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/providers/tags/tags_provider.dart';
import 'package:medito/utils/tag_labels.dart';
import 'package:medito/views/tags/tag_view.dart';
import 'package:medito/views/tags/widgets/tag_chip.dart';

/// Tags that describe almost everything or nothing a listener would pick by,
/// so they never show as chips.
const hiddenTagIds = <String>{
  'guided_meditation',
  'course_lesson',
  'habit_building',
  'reflection',
  'sound',
  'on_the_go',
  'experienced',
};

void openTag(BuildContext context, TagModel tag) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => TagView(tag: tag)));
}

/// Horizontal strip of every browsable tag, most-used first. Renders nothing
/// while the catalog is loading or when it is unavailable.
class ExploreTagChips extends ConsumerWidget {
  const ExploreTagChips({super.key, this.padding = EdgeInsets.zero});

  /// Applied only when chips actually render, so an unavailable catalog leaves
  /// no gap.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(tagCatalogProvider);
    if (catalog.isEmpty) return const SizedBox.shrink();

    final counts = catalog.trackCounts;
    final tags =
        catalog.tags
            .where(
              (t) => !hiddenTagIds.contains(t.id) && (counts[t.id] ?? 0) > 0,
            )
            .toList()
          ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    if (tags.isEmpty) return const SizedBox.shrink();

    // Sized by its chips rather than a fixed height, so larger text isn't
    // clipped. Eager is fine: the catalog has a few dozen tags at most.
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: padding16, vertical: 2),
        child: Row(
          children: [
            for (final tag in tags) ...[
              if (tag != tags.first) const SizedBox(width: padding8),
              TagChip(
                key: ValueKey('tag_chip_${tag.id}'),
                label: tagLabel(context, tag.id),
                onTap: () => openTag(context, tag),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wrapping row of chips for a given list of tags; nothing when empty.
class TagChipsWrap extends StatelessWidget {
  const TagChipsWrap({
    super.key,
    required this.tags,
    this.max = 6,
    this.padding = EdgeInsets.zero,
  });

  final List<TagModel> tags;
  final int max;

  /// Applied only when there are chips to show, so an empty result leaves no
  /// gap in the surrounding layout.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visible = tags
        .where((t) => !hiddenTagIds.contains(t.id))
        .take(max)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: padding8,
        // Each chip's 48px touch target already leaves a gap between rows.
        runSpacing: 0,
        children: [
          for (final tag in visible)
            TagChip(
              key: ValueKey('tag_chip_${tag.id}'),
              label: tagLabel(context, tag.id),
              onTap: () => openTag(context, tag),
            ),
        ],
      ),
    );
  }
}

/// A track's own tags, strongest first. Nothing when the track has none or
/// the catalog is unavailable.
class TrackTagChips extends ConsumerWidget {
  const TrackTagChips({
    super.key,
    required this.trackId,
    this.padding = EdgeInsets.zero,
  });

  final String trackId;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TagChipsWrap(
      tags: ref.watch(trackTagsProvider(trackId)),
      padding: padding,
    );
  }
}

/// Tags shared by at least half of a pack's tracks. Packs are not tagged on
/// the server; this is derived from the track map on the device.
class PackTagChips extends ConsumerWidget {
  const PackTagChips({
    super.key,
    required this.trackIds,
    this.padding = EdgeInsets.zero,
  });

  final List<String> trackIds;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(tagCatalogProvider);
    return TagChipsWrap(
      tags: catalog.tagsForTracks(trackIds),
      padding: padding,
    );
  }
}
