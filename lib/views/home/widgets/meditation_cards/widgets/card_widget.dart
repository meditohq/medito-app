import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class CardWidget extends StatelessWidget {
  const CardWidget({
    super.key,
    this.tag,
    required this.title,
    required this.coverUrlPath,
    this.onTap,
  });
  final String? tag;
  final String title;
  final String coverUrlPath;
  final void Function()? onTap;
  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    var boxDecoration = BoxDecoration(
      color: ColorConstants.transparent,
    );

    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          SizedBox(
            width: 154,
            child: Container(
              foregroundDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ColorConstants.almostBlack.withOpacity(0.15),
                    ColorConstants.almostBlack,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: NetworkImageWidget(
                url: coverUrlPath,
                isCache: true,
              ),
            ),
          ),
          Container(
            width: 154,
            decoration: boxDecoration,
            child: _tagAndTitle(textTheme, tag: tag, title: title),
          ),
        ],
      ),
    );
  }

  Column _tagAndTitle(
    TextTheme textTheme, {
    String? tag,
    required String title,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (tag != null) _tag(textTheme, tag: tag) else SizedBox(),
        _title(textTheme, title: title),
      ],
    );
  }

  Padding _tag(TextTheme textTheme, {String? tag}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Container(
        color: ColorConstants.ashWhite,
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          tag ?? '',
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: ColorConstants.black,
            fontFamily: DmMono,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Padding _title(TextTheme textTheme, {required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelMedium?.copyWith(letterSpacing: 0, height: 1.1),
      ),
    );
  }
}
