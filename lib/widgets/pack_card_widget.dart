import 'package:medito/constants/constants.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';

class PackCardWidget extends StatefulWidget {
  const PackCardWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.coverUrlPath,
    this.onTap,
  });

  final String title;
  final String? subTitle;
  final String? coverUrlPath;
  final void Function()? onTap;

  @override
  State<PackCardWidget> createState() => _PackCardWidgetState();
}

class _PackCardWidgetState extends State<PackCardWidget> {
  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);

    final backgroundColor = theme.cardColor;
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.onSurface;

    return HomeGradientBorder(
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
                  _title(textTheme, title: widget.title, color: titleColor),
                  if (widget.subTitle != null) const SizedBox(height: 4),
                  _description(
                    textTheme,
                    subtitle: widget.subTitle,
                    color: subtitleColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Text _title(
    TextTheme textTheme, {
    required String title,
    required Color color,
  }) {
    return Text(
      title,
      style: textTheme.displayLarge?.copyWith(
        fontFamily: dmSans,
        height: 1.2,
        color: color,
      ),
    );
  }

  Widget _description(
    TextTheme textTheme, {
    String? subtitle,
    required Color color,
  }) {
    if (subtitle != null) {
      return Text(
        subtitle,
        style: textTheme.titleMedium?.copyWith(
          letterSpacing: 0,
          color: color,
          fontSize: 14,
          height: 1.4,
        ),
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
