import 'package:flutter/material.dart';

import 'widgets/box_shimmer_widget.dart';

/// Loading placeholder for [TrackView]. Mirrors its portrait layout (16:9
/// cover, title, description, pickers, play button) so nothing jumps when the
/// track arrives. Sizes itself to the parent's width — the caller supplies the
/// page padding and scrolling, exactly as it does for the loaded content.
class TrackShimmerWidget extends StatelessWidget {
  const TrackShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Same threshold TrackView uses to put the two pickers side by side.
    final useCompactLayout = MediaQuery.of(context).size.height < 700;

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
        // Title
        const BoxShimmerWidget(height: 24, width: 220, borderRadius: 6),
        const SizedBox(height: 16),
        // Description
        const BoxShimmerWidget(
          height: 14,
          width: double.infinity,
          borderRadius: 6,
        ),
        const SizedBox(height: 8),
        const BoxShimmerWidget(
          height: 14,
          width: double.infinity,
          borderRadius: 6,
        ),
        const SizedBox(height: 8),
        const FractionallySizedBox(
          widthFactor: 0.6,
          child: BoxShimmerWidget(
            height: 14,
            width: double.infinity,
            borderRadius: 6,
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
