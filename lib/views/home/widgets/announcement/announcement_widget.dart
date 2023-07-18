import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/home/announcement/announcement_model.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AnnouncementWidget extends StatelessWidget {
  const AnnouncementWidget({super.key, required this.announcement});
  final AnnouncementModel announcement;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorConstants.getColorFromString(announcement.colorBackground),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icon(),
              _text(context),
            ],
          ),
          height16,
          _actionBtn(),
        ],
      ),
    );
  }

  Row _actionBtn() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        LoadingButtonWidget(
          onPressed: () {},
          btnText: StringConstants.dismiss,
          bgColor: ColorConstants.lightPurple,
          textColor: ColorConstants.walterWhite,
          elevation: 0,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        LoadingButtonWidget(
          onPressed: () {},
          btnText: StringConstants.watch,
          bgColor: ColorConstants.walterWhite,
          textColor: ColorConstants.lightPurple,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ],
    );
  }

  Flexible _text(BuildContext context) {
    return Flexible(
      child: Text(
        announcement.text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ColorConstants.getColorFromString(
                announcement.colorText,
              ),
            ),
      ),
    );
  }

  Widget _icon() {
    if (announcement.icon != null) {
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
}
