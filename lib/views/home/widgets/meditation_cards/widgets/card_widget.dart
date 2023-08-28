import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CardWidget extends ConsumerStatefulWidget {
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
  ConsumerState<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends ConsumerState<CardWidget> {
  double _scale = 1.0;

  void _onTapDown() {
    setState(() {
      _scale = _scale == 1.0 ? 0.95 : 1.0;
    });
  }

  void _onTapUp() {
    setState(() {
      _scale = _scale == 0.95 ? 1.0 : 0.95;
    });
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 5),
          curve: Curves.easeInOut,
          width: 154 * _scale,
          height: _scale == 0.95 ? 154 * _scale : 156 * _scale,
          child: NetworkImageWidget(
            url: widget.coverUrlPath,
            isCache: true,
            gradient: LinearGradient(
              colors: [
                ColorConstants.almostBlack.withOpacity(0.15),
                ColorConstants.almostBlack,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: _onTapUp,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 154 * _scale,
            height: 154 * _scale,
            color: ColorConstants.transparent,
            child:
                _tagAndTitle(textTheme, tag: widget.tag, title: widget.title),
          ),
        ),
      ],
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
