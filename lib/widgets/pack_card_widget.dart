import 'package:medito/constants/constants.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:medito/views/pack/widgets/pack_complete_badge.dart';

class PackCardWidget extends StatefulWidget {
  const PackCardWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.coverUrlPath,
    this.onTap,
    this.isCompleted = false,
  });

  final String title;
  final String? subTitle;
  final String? coverUrlPath;
  final void Function()? onTap;

  /// Shows a tick when every session in the pack is complete.
  final bool isCompleted;

  @override
  State<PackCardWidget> createState() => _PackCardWidgetState();
}

class _PackCardWidgetState extends State<PackCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor = theme.cardColor;
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.onSurface;

    final card = HomeGradientBorder(
      backgroundColor: backgroundColor,
      borderRadius: 14,
      borderWidth: 0.5,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.coverUrlPath != null && widget.coverUrlPath!.isNotEmpty)
              _getCoverUrl(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _title(title: widget.title, color: titleColor),
                  if (widget.subTitle != null) const SizedBox(height: 4),
                  _description(subtitle: widget.subTitle, color: subtitleColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // One button reading title, subtitle and (when done) "Completed": the
    // badge sits outside the InkWell, so without the merge it was a separate
    // stop.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: !widget.isCompleted
            ? card
            : Stack(
                children: [
                  card,
                  // Decorative: let taps on the badge reach the card's InkWell.
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: IgnorePointer(child: PackCompleteBadge()),
                  ),
                ],
              ),
      ),
    );
  }

  Text _title({required String title, required Color color}) {
    return Text(title, style: context.text.title.copyWith(color: color));
  }

  Widget _description({String? subtitle, required Color color}) {
    if (subtitle != null) {
      return Text(
        subtitle,
        style: context.text.bodySmall.copyWith(color: color),
      );
    }

    return const SizedBox();
  }

  Widget _getCoverUrl() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14),
        topRight: Radius.circular(14),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: NetworkImageWidget(
          url: widget.coverUrlPath ?? '',
          shouldCache: true,
        ),
      ),
    );
  }
}
