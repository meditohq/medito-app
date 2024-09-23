import 'dart:async';

import 'package:medito/constants/constants.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        var backgroundColor = colorScheme?.primaryContainer ?? ColorConstants.onyx;
        var titleColor = colorScheme?.onPrimaryContainer ?? Colors.white;
        var subtitleColor = colorScheme?.onPrimaryContainer ?? ColorConstants.graphite;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: subTitle != null
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          _title(textTheme, title: title, color: titleColor),
                          if (subTitle != null) height4,
                          _description(
                            textTheme,
                            subtitle: subTitle,
                            color: subtitleColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (coverUrlPath != null && coverUrlPath!.isNotEmpty)
                    _getCoverUrl(),
                ],
              ),
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
        print('Error generating ColorScheme: $e');
        return null;
      }
    }
    return null;
  }

  Text _title(TextTheme textTheme, {required String title, required Color color}) {
    return Text(
      title,
      style: textTheme.displayLarge?.copyWith(
        fontFamily: SourceSerif,
        height: 0,
        color: color,
      ),
    );
  }

  Widget _description(TextTheme textTheme, {String? subtitle, required Color color}) {
    if (subtitle != null) {
      return Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
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
    if (coverUrlPath == null || coverUrlPath!.isEmpty) {
      return const SizedBox(width: 100); // Placeholder with width
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(14),
        bottomRight: Radius.circular(14),
      ),
      child: SizedBox(
        height: 100,
        width: 100,
        child: NetworkImageWidget(
          url: coverUrlPath!,
          shouldCache: true,
        ),
      ),
    );
  }
}
