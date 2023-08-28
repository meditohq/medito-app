import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AnnouncementWidget extends ConsumerWidget {
  const AnnouncementWidget({super.key, required this.announcement});
  final AnnouncementModel announcement;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var bgColor =
        ColorConstants.getColorFromString(announcement.colorBackground);

    return Column(
      children: [
        Container(
          color: bgColor,
          height: MediaQuery.of(context).viewPadding.top,
        ),
        Container(
          color: bgColor,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _icon(announcement.icon),
                  _text(context, announcement.text),
                ],
              ),
              height16,
              _actionBtn(context, ref, announcement),
            ],
          ),
        ),
      ],
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        LoadingButtonWidget(
          onPressed: () {
            _handleTrackEvent(ref, announcement.id, StringConstants.dismiss);
            ref.invalidate(homeProvider);
            ref.read(homeProvider);
          },
          btnText: StringConstants.dismiss,
          bgColor: bgColor,
          textColor: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          elevation: 0,
        ),
        width4,
        LoadingButtonWidget(
          onPressed: () => _handleCtaTitlePress(context, ref, announcement),
          btnText: announcement.ctaTitle ?? '',
          bgColor: textColor,
          textColor: bgColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          elevation: 0,
        ),
      ],
    );
  }

  Flexible _text(BuildContext context, String? title) {
    return Flexible(
      child: Text(
        title ?? '',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ColorConstants.getColorFromString(
                announcement.colorText,
              ),
              fontSize: 14,
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
            formatIcon(announcement.icon!),
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
  ) {
    var location = GoRouter.of(context).location;
    _handleTrackEvent(ref, element.id, element.ctaTitle);
    if (element.ctaType == TypeConstants.LINK) {
      context.push(
        location + RouteConstants.webviewPath,
        extra: {'url': element.ctaPath},
      );
    }
    context.push(getPathFromString(
      element.ctaType,
      [element.ctaPath.toString().getIdFromPath()],
    ));
  }

  void _handleTrackEvent(WidgetRef ref, String announcementId, String? ctaTitle) {
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
