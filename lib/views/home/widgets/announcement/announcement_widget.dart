import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnouncementWidget extends ConsumerStatefulWidget {
  const AnnouncementWidget({
    super.key,
    required this.announcement,
    this.onPressedDismiss,
  });

  final AnnouncementModel announcement;
  final void Function()? onPressedDismiss;

  @override
  ConsumerState<AnnouncementWidget> createState() => _AnnouncementWidgetState();
}

class _AnnouncementWidgetState extends ConsumerState<AnnouncementWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _animationController.reverse().then((_) {
      widget.onPressedDismiss?.call();
      _handleTrackEvent();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcement.text == null) {
      return const SizedBox.shrink();
    }

    var bgColor =
        ColorConstants.getColorFromString(widget.announcement.colorBackground);

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(top: padding8, left: padding16, right: padding16),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.only(left: padding16, right: padding16, bottom: padding16, top: padding24),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(context),
                  ],
                ),
                height16,
                _actionBtn(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Row _actionBtn(
    BuildContext context,
  ) {
    var textColor = ColorConstants.getColorFromString(
      widget.announcement.colorText,
    );
    var bgColor = ColorConstants.getColorFromString(
      widget.announcement.colorBackground,
    );

    var actionWidgets = <Widget>[
      LoadingButtonWidget(
        onPressed: _handleDismiss,
        btnText: StringConstants.dismiss,
        bgColor: bgColor,
        textColor: textColor,
        elevation: 0,
      ),
      width4,
    ];

    if (widget.announcement.ctaPath != null) {
      actionWidgets.add(LoadingButtonWidget(
        onPressed: () => _handleCtaTitlePress(context),
        btnText: widget.announcement.ctaTitle ?? '',
        bgColor: textColor,
        textColor: bgColor,
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
    );
  }

  Flexible _text(BuildContext context) {
    var markDownTheme = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ColorConstants.getColorFromString(
            widget.announcement.colorText,
          ),
          fontSize: 14,
        );

    return Flexible(
      child: MarkdownWidget(
        body: widget.announcement.text ?? '',
        selectable: true,
        textAlign: WrapAlignment.start,
        a: markDownTheme?.copyWith(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w700,
        ),
        p: markDownTheme?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _handleCtaTitlePress(
    BuildContext context,
  ) async {
    var path = widget.announcement.ctaPath;
    await handleNavigation(
      widget.announcement.ctaType,
      [path.toString().getIdFromPath(), path],
      context,
      ref: ref,
    );
  }

  void _handleTrackEvent() {
    var id = widget.announcement.id;
    if (id.isNotNullAndNotEmpty()) {
      ref.read(
        announcementDismissEventProvider(
          id: id!,
        ),
      );
    }
  }
}
