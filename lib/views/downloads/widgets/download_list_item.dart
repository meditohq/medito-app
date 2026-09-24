import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

const _coverSize = 64.0;
const _coverRadius = 12.0;
const _rowPadding = EdgeInsets.fromLTRB(16, 8, 4, 8);

//ignore:prefer-match-file-name
class DownloadListItemWidget extends StatelessWidget {
  const DownloadListItemWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.index,
  });

  final String title;
  final String subtitle;
  final String coverUrl;

  /// Position in the reorderable list, for the drag handle.
  final int index;

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
              child: NetworkImageWidget(url: coverUrl, shouldCache: true),
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
                  style: textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: textTheme.titleMedium),
                ],
              ],
            ),
          ),
          // Explicit handle: the default long-press-to-drag on phones gave no
          // hint that the list could be reordered at all.
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
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      itemBuilder: (context, _) => const Padding(
        padding: _rowPadding,
        child: Row(
          children: [
            BoxShimmerWidget(
              width: _coverSize,
              height: _coverSize,
              borderRadius: _coverRadius,
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BoxShimmerWidget(width: 180, height: 18, borderRadius: 6),
                SizedBox(height: 8),
                BoxShimmerWidget(width: 120, height: 14, borderRadius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
