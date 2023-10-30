import 'package:Medito/constants/constants.dart';
import 'package:Medito/views/home/widgets/meditation_cards/widgets/animated_scale_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CardWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedScaleWidget(
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3.5),
      child: Stack(
        children: [
          _buildImage(),
          _buildGestureDetector(context),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return SizedBox(
      width: 154,
      height: 154,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.5),
        child: Container(
          foregroundDecoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ColorConstants.black.withOpacity(0),
                ColorConstants.black.withOpacity(0.5),
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
    );
  }

  Widget _buildGestureDetector(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 154,
        height: 154,
        color: ColorConstants.transparent,
        child: _tagAndTitle(context),
      ),
    );
  }

  Widget _tagAndTitle(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (tag != null) _tag(context) else const SizedBox(),
        _title(context),
      ],
    );
  }

  Widget _tag(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        color: ColorConstants.onyx,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          tag!,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: ColorConstants.walterWhite,
            fontFamily: DmMono,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        maxLines: 4,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelMedium?.copyWith(letterSpacing: 0, height: 1.2),
      ),
    );
  }
}