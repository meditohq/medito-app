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

class _AnnouncementWidgetState extends ConsumerState<AnnouncementWidget> {
  @override
  Widget build(BuildContext context) {
    var bgColor =
        ColorConstants.getColorFromString(widget.announcement.colorBackground);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
      ),
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icon(widget.announcement.icon),
              _text(context),
            ],
          ),
          height16,
          _actionBtn(context),
        ],
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
        onPressed: () {
          widget.onPressedDismiss?.call();
          _handleTrackEvent();
        },
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

  Widget _icon(String? icon) {
    if (icon.isNotNullAndNotEmpty()) {
      return Padding(
        padding: const EdgeInsets.only(top: 0, right: 10),
        child: Icon(
          IconData(
            formatIcon(icon!),
            fontFamily: materialIcons,
          ),
          size: 24,
        ),
      );
    }

    return SizedBox();
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
