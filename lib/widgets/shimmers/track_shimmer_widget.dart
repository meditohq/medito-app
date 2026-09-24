import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/tags/tags_provider.dart';

import 'widgets/box_shimmer_widget.dart';

/// Loading placeholder for [TrackView]. Mirrors its portrait layout (16:9
/// cover, title, description, tags, pickers, play button) so nothing jumps
/// when the track arrives. Sizes itself to the parent's width — the caller
/// supplies the page padding and scrolling, exactly as it does for the loaded
/// content.
class TrackShimmerWidget extends ConsumerWidget {
  const TrackShimmerWidget({super.key});

  // Line boxes of the real text: font size × the theme's 1.3 line height.
  static const _titleLineHeight = 22 * 1.3;
  static const _descriptionLineHeight = 16 * 1.3;
  // TagChip: one 16px × 1.3 line plus 8px vertical padding each side.
  static const _chipHeight = 16 * 1.3 + 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same threshold TrackView uses to put the two pickers side by side.
    final useCompactLayout = MediaQuery.of(context).size.height < 700;
    // Track tags only render once the catalog is loaded, so only reserve
    // their row then.
    final showTags = !ref.watch(tagCatalogProvider).isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: BoxShimmerWidget(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 20,
          ),
        ),
        const SizedBox(height: 24),
        const _LineShimmer(lineHeight: _titleLineHeight, widthFactor: 0.6),
        const SizedBox(height: 8),
        const _LineShimmer(lineHeight: _descriptionLineHeight),
        const _LineShimmer(lineHeight: _descriptionLineHeight),
        const _LineShimmer(
          lineHeight: _descriptionLineHeight,
          widthFactor: 0.6,
        ),
        if (showTags)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Row(
              children: [
                BoxShimmerWidget(
                  height: _chipHeight,
                  width: 96,
                  borderRadius: _chipHeight / 2,
                ),
                SizedBox(width: 8),
                BoxShimmerWidget(
                  height: _chipHeight,
                  width: 72,
                  borderRadius: _chipHeight / 2,
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        // Guide + duration pickers
        if (useCompactLayout)
          const Row(
            children: [
              Expanded(child: _PickerShimmer()),
              SizedBox(width: 12),
              Expanded(child: _PickerShimmer()),
            ],
          )
        else ...const [
          _PickerShimmer(),
          SizedBox(height: 12),
          _PickerShimmer(),
        ],
        const SizedBox(height: 12),
        // Play button
        const BoxShimmerWidget(
          height: 56,
          width: double.infinity,
          borderRadius: 28,
        ),
      ],
    );
  }
}

/// One line of text: a bar vertically centred in the line's full height, so
/// the placeholder takes exactly the space the real line will.
class _LineShimmer extends StatelessWidget {
  const _LineShimmer({required this.lineHeight, this.widthFactor = 1});

  final double lineHeight;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: BoxShimmerWidget(
            height: lineHeight * 0.6,
            width: double.infinity,
            borderRadius: 6,
          ),
        ),
      ),
    );
  }
}

class _PickerShimmer extends StatelessWidget {
  const _PickerShimmer();

  @override
  Widget build(BuildContext context) {
    return const BoxShimmerWidget(
      height: 48,
      width: double.infinity,
      borderRadius: 7,
    );
  }
}
