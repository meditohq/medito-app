import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
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
    return Container(
      color: ColorConstants.getColorFromString(announcement.colorBackground),
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
    );
  }

  Row _actionBtn(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: InkWell(
            onTap: () {
              ref.invalidate(homeProvider);
              ref.read(homeProvider);
              _handleTrackEvent(ref, announcement.id, StringConstants.dismiss);
            },
            child: Text(
              StringConstants.dismiss,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: ClashDisplay,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        LoadingButtonWidget(
          onPressed: () {
            _handleTrackEvent(ref, announcement.id, announcement.ctaTitle);
            // var location = GoRouter.of(context).location;
            // context.push(
            //   location + RouteConstants.webviewPath,
            //   extra: {'url': announcement.path},
            // );
          },
          btnText: StringConstants.watch,
          bgColor: ColorConstants.walterWhite,
          textColor: ColorConstants.lightPurple,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ],
    );
  }

  Flexible _text(BuildContext context, String? title) {
    return Flexible(
      child: Text(
        title ?? '',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ColorConstants.getColorFromString(
                announcement.colorText,
              ),
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
        ),
      );
    }

    return SizedBox();
  }

  void _handleTrackEvent(WidgetRef ref, int announcementId, String? ctaTitle) {
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
