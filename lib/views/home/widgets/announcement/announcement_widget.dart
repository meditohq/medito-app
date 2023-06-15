import 'package:Medito/constants/constants.dart';
import 'package:Medito/constants/strings/string_constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AnnouncementWidget extends StatelessWidget {
  const AnnouncementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorConstants.lightPurple,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: Icon(Icons.hourglass_bottom),
              ),
              Flexible(
                child: Text(
                  '''We just had the most incredible time at the second medito retreat. Watch the video to see some highlights.''',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          height16,
          Row(
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
          ),
        ],
      ),
    );
  }
}
