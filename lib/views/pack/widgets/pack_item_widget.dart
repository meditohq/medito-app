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

    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(width: 2, color: ColorConstants.charcoal),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    ),
                  ),
                if (hasSubtitle)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.subtitle,
                        style: bodyLarge?.copyWith(
                          fontFamily: DmMono,
                          color: ColorConstants.graphite,
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
    );
  }

  Widget _getIcon(String type, {bool? isCompletedTrack}) {
    if (type == TypeConstants.LINK) {
      return SvgPicture.asset(AssetConstants.icLink);
    } else if (type == TypeConstants.TRACK && isCompletedTrack == true) {
      return Icon(
          color: ColorConstants.graphite,
          Icons.check,);
    }

    return SizedBox();
  }
}
