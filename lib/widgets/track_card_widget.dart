import 'package:medito/constants/constants.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class TrackCardWidget extends StatelessWidget {
  const TrackCardWidget({
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
  Widget build(BuildContext context) {
    return HomeGradientBorder(
      backgroundColor: Theme.of(context).cardColor,
      borderRadius: 14,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Without the role the card reads as plain text.
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: subTitle != null
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      _title(context, title: title),
                      if (subTitle != null) height4,
                      _description(context, subtitle: subTitle),
                    ],
                  ),
                ),
                width12,
                _getCoverUrl(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Text _title(BuildContext context, {required String title}) {
    return Text(title, style: context.text.title);
  }

  Widget _description(BuildContext context, {String? subtitle}) {
    if (subtitle != null) {
      return Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        style: context.text.muted.bodySmall,
      );
    }

    return const SizedBox();
  }

  Widget _getCoverUrl() {
    if (coverUrlPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 80,
          width: 80,
          child: NetworkImageWidget(url: coverUrlPath ?? '', shouldCache: true),
        ),
      );
    }

    return const SizedBox();
  }
}
