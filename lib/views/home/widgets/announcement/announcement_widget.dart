import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
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
    var size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: size.width,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 24),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _icon(widget.announcement.icon),
                _text(context, widget.announcement.text),
              ],
            ),
            height16,
            _actionBtn(context, ref, widget.announcement),
          ],
        ),
      ),
    );
  }

  Row _actionBtn(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) {
    var textColor = ColorConstants.getColorFromString(
      announcement.colorText,
    );
    var bgColor = ColorConstants.getColorFromString(
      announcement.colorBackground,
    );

    var actionWidgets = <Widget>[
      LoadingButtonWidget(
        onPressed: () {
          widget.onPressedDismiss?.call();
          _handleTrackEvent(
            ref,
            announcement.id,
            StringConstants.dismiss.toLowerCase(),
          );
        },
        btnText: StringConstants.dismiss,
        bgColor: bgColor,
        textColor: textColor,
        elevation: 0,
      ),
      width4,
    ];

    if (announcement.ctaPath != null) {
      actionWidgets.add(LoadingButtonWidget(
        onPressed: () => _handleCtaTitlePress(context, ref, announcement),
        btnText: announcement.ctaTitle ?? '',
        bgColor: textColor,
        textColor: bgColor,
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
    );
  }

  Flexible _text(BuildContext context, String? title) {
    var markDownTheme = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ColorConstants.getColorFromString(
            widget.announcement.colorText,
          ),
          fontSize: 14,
        );

    return Flexible(
      child: MarkdownWidget(
        body: title ?? '',
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
    if (icon != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 0, right: 10),
        child: Icon(
          IconData(
            formatIcon(widget.announcement.icon!),
            fontFamily: 'MaterialIcons',
          ),
          size: 24,
        ),
      );
    }

    return SizedBox();
  }

  void _handleCtaTitlePress(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel element,
  ) async {
    _handleTrackEvent(ref, element.id, element.ctaTitle);
    await handleNavigation(
      context: context,
      element.ctaType,
      [element.ctaPath.toString().getIdFromPath(), element.ctaPath],
      ref: ref,
    );
  }

  void _handleTrackEvent(
    WidgetRef ref,
    String announcementId,
    String? ctaTitle,
  ) {
    var announcement = AnnouncementCtaTappedModel(
      announcementId: announcementId,
      ctaTitle: ctaTitle ?? '',
    );
    var event = EventsModel(
      name: EventTypes.announcementCtaTapped,
      payload: announcement.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
