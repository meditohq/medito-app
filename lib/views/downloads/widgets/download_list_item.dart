import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

const _coverSize = 72.0;
const _coverRadius = 14.0;
const _rowPadding = EdgeInsets.fromLTRB(12, 12, 4, 12);

//ignore:prefer-match-file-name
class DownloadListItemWidget extends StatelessWidget {
  const DownloadListItemWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.index,
    this.trailing,
    this.status,
    this.showReorder = true,
  });

  final String title;
  final String subtitle;
  final String coverUrl;

  /// Position in the reorderable list, for the drag handle.
  final int index;
  final Widget? trailing;
  final Widget? status;
  final bool showReorder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_coverRadius),
            // The cached image path ignores width/height, so size it here.
            child: SizedBox.square(
              dimension: _coverSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageWidget(url: coverUrl, shouldCache: true),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(5),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.headlineMedium?.copyWith(letterSpacing: 0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.titleMedium?.copyWith(letterSpacing: 0),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                ?status,
              ],
            ),
          ),
          ?trailing,
          // Explicit handle: the default long-press-to-drag on phones gave no
          // hint that the list could be reordered at all.
          if (showReorder)
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: AppLocalizations.of(context)!.reorder,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: MeditoIcon(
                      assetName: MeditoIcons.dragHandle,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Loading placeholder shaped like the download rows above.
class DownloadListShimmer extends StatelessWidget {
  const DownloadListShimmer({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      itemBuilder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Padding(
            padding: _rowPadding,
            child: Row(
              children: [
                BoxShimmerWidget(
                  width: _coverSize,
                  height: _coverSize,
                  borderRadius: _coverRadius,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BoxShimmerWidget(width: 180, height: 18, borderRadius: 6),
                      SizedBox(height: 8),
                      BoxShimmerWidget(width: 120, height: 14, borderRadius: 6),
                    ],
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
