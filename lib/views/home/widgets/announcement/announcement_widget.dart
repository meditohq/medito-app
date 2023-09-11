import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    with TickerProviderStateMixin {
  bool _isCollapsed = true;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _toggleCollapse();
    });
    super.initState();
  }

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    var bgColor =
        ColorConstants.getColorFromString(widget.announcement.colorBackground);
    var topPadding = MediaQuery.of(context).viewPadding.top;
    var size = MediaQuery.of(context).size;

    return Column(
      children: [
        SizeTransition(
          axisAlignment: -1.0,
          sizeFactor: _isCollapsed
              ? Tween<double>(begin: 1.0, end: 0.0).animate(
                  CurvedAnimation(
                    parent: AnimationController(
                      vsync: this,
                      duration: Duration(milliseconds: 500),
                    )..forward(),
                    curve: Curves.easeInOut,
                  ),
                )
              : Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: AnimationController(
                      vsync: this,
                      duration: Duration(milliseconds: 500),
                    )..forward(),
                    curve: Curves.easeInOut,
                  ),
                ),
          child: Container(
            color: bgColor,
            width: size.width,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: topPadding,
                  width: size.width,
                ),
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
        ),
        if (_isCollapsed)
          SizedBox(
            height: topPadding,
          ),
        InkWell(
          onTap: () {
            _toggleCollapse();
          },
          child: Icon(
            Icons.abc,
            size: 50,
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
            // if (widget.onPressedDismiss != null) {
            //   widget.onPressedDismiss!();
            // }
            _toggleCollapse();
            // _handleTrackEvent(
            //   ref,
            //   announcement.id,
            //   StringConstants.dismiss.toLowerCase(),
            // );
            // ref.invalidate(remoteStatsProvider);
            // ref.read(remoteStatsProvider);
            // ref.invalidate(homeProvider);
            // ref.read(homeProvider);
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
      child: SelectableText(
        title ?? '',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ColorConstants.getColorFromString(
                widget.announcement.colorText,
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
    if (element.ctaType == TypeConstants.EMAIL) {
      var deviceAppAndUserInfo =
          await ref.read(deviceAppAndUserInfoProvider.future);
      unawaited(launchEmailSubmission(
        element.ctaPath.toString(),
        body: deviceAppAndUserInfo,
      ));
    } else {
      unawaited(context.push(
        getPathFromString(
          element.ctaType,
          [element.ctaPath.toString().getIdFromPath()],
        ),
        extra: {'url': element.ctaPath},
      ));
    }
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
