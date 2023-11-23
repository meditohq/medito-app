import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PackItemWidget extends StatelessWidget {
  const PackItemWidget({super.key, required this.item, required this.isLast});

  final PackItemsModel item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    var bodyLarge = Theme.of(context).primaryTextTheme.bodyLarge;
    var hasSubtitle = item.subtitle.isNotNullAndNotEmpty();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            padding: EdgeInsets.only(top: hasSubtitle ? 24 : 20, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.title.isNotNullAndNotEmpty())
                        Text(
                          item.title,
                          style: bodyLarge?.copyWith(
                            color: ColorConstants.walterWhite,
                            fontFamily: DmSans,
                            fontSize: 16,
                          ),
                        ),
                      if (hasSubtitle)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.subtitle ?? '',
                              style: bodyLarge?.copyWith(
                                fontFamily: DmMono,
                                color: ColorConstants.graphite,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _getIcon(item.type, isCompletedTrack: item.isCompleted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIcon(String type, {bool? isCompletedTrack}) {
    if (type == TypeConstants.link) {
      return SvgPicture.asset(AssetConstants.icLink);
    } else if (type == TypeConstants.track && isCompletedTrack == true) {
      return Icon(
        color: ColorConstants.graphite,
        Icons.check,
      );
    }

    return SizedBox();
  }
}
