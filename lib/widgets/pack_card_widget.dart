import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';

class PackCardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return FutureBuilder<ColorScheme?>(
      future: _generateColorScheme(context),
      builder: (context, snapshot) {
        var colorScheme = snapshot.data;
        var backgroundColor =
            colorScheme?.primaryContainer ?? ColorConstants.onyx;
        var titleColor = colorScheme?.onPrimaryContainer ?? Colors.white;
        var subtitleColor = colorScheme?.onPrimaryContainer ?? Colors.white;

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverUrlPath != null && coverUrlPath!.isNotEmpty)
                  _getCoverUrl(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(textTheme, title: title, color: titleColor),
                      if (subTitle != null) const SizedBox(height: 4),
                      _description(
                        textTheme,
                        subtitle: subTitle,
                        color: subtitleColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<ColorScheme?> _generateColorScheme(BuildContext context) async {
    if (coverUrlPath != null && coverUrlPath!.isNotEmpty) {
      try {
        var image = CachedNetworkImageProvider(coverUrlPath!);

        return await ColorScheme.fromImageProvider(
          provider: image,
          brightness: Brightness.dark,
          contrastLevel: 1,
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          throw TimeoutException('ColorScheme generation timed out');
        });
      } catch (e) {
        return null;
      }
    }
    return null;
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
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
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
        aspectRatio: 4 / 3,
        child: NetworkImageWidget(
          url: coverUrlPath ?? '',
          shouldCache: true,
        ),
      ),
    );
  }
}
