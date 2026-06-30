import 'package:medito/constants/constants.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
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

class _AnnouncementWidgetState extends ConsumerState<AnnouncementWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
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
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcement.text == null) {
      return const SizedBox.shrink();
    }

    final rawBgColor = ColorConstants.getColorFromString(
      widget.announcement.colorBackground,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? rawBgColor
        : Color.lerp(rawBgColor, Colors.black, 0.08) ?? rawBgColor;

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(
            top: padding8,
            left: padding16,
            right: padding16,
            bottom: padding16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.only(
              left: padding16,
              right: padding16,
              bottom: padding12,
              top: padding24,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_text(context)],
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

  Row _actionBtn(BuildContext context) {
    var textColor = ColorConstants.getColorFromString(
      widget.announcement.colorText,
    );
    var bgColor = ColorConstants.getColorFromString(
      widget.announcement.colorBackground,
    );

    var actionWidgets = <Widget>[
      TextButton(
        onPressed: _handleDismiss,
        child: Text(
          AppLocalizations.of(context)!.dismiss,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: textColor),
        ),
      ),
      width4,
    ];

    if (widget.announcement.ctaPath != null) {
      actionWidgets.add(
        ElevatedButton(
          onPressed: () => _handleCtaTitlePress(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: textColor,
            foregroundColor: bgColor,
            padding: const EdgeInsets.all(8),
          ),
          child: Text(widget.announcement.ctaTitle ?? ''),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
    );
  }

  Flexible _text(BuildContext context) {
    var textColor = ColorConstants.getColorFromString(
      widget.announcement.colorText,
    );

    var markDownTheme = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: textColor);

    return Flexible(
      child: MarkdownWidget(
        body: widget.announcement.text ?? '',
        selectable: true,
        textAlign: WrapAlignment.start,
        a: markDownTheme?.copyWith(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w700,
        ),
        p: markDownTheme?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  void _handleCtaTitlePress(BuildContext context) async {
    var path = widget.announcement.ctaPath;
    var type = widget.announcement.ctaType;
    var isDonation =
        type == 'donation' ||
        (type == TypeConstants.route && path == RouteConstants.donation);
    await handleNavigation(
      type,
      [path.toString().getIdFromPath(), path],
      context,
      ref: ref,
      sourceRouteName: isDonation
          ? FirebaseAnalyticsService.paywallSourceAnnouncement
          : null,
    );
  }
}
