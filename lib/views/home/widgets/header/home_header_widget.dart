import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../bottom_sheet/stats/stats_bottom_sheet_widget.dart';
import '../bottom_sheet/menu/menu_bottom_sheet_widget.dart';

class HomeHeaderWidget extends StatelessWidget {
  const HomeHeaderWidget({
    super.key,
    this.streakCount,
    required this.homeMenuModel,
  });
  final String? streakCount;
  final List<HomeMenuModel> homeMenuModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset(AssetConstants.icLogo),
          Row(
            children: [
              _statsWidget(context, streakCount: streakCount),
              width16,
              _downloadWidget(context),
              width16,
              _menuWidget(context),
            ],
          ),
        ],
      ),
    );
  }

  InkWell _menuWidget(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: ColorConstants.transparent,
          builder: (BuildContext context) {
            return MenuBottomSheetWidget(
              homeMenuModel: homeMenuModel,
            );
          },
        );
      },
      child: SvgPicture.asset(AssetConstants.icMenu),
    );
  }

  InkWell _downloadWidget(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RouteConstants.collectionPath),
      child: SvgPicture.asset(
        AssetConstants.icDownload,
      ),
    );
  }

  InkWell _statsWidget(BuildContext context, {String? streakCount}) {
    return InkWell(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: ColorConstants.transparent,
          builder: (BuildContext context) {
            return StatsBottomSheetWidget();
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 1,
            color: ColorConstants.walterWhite,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        child: Row(
          children: [
            SvgPicture.asset(AssetConstants.icStreak),
            width4,
            Text(
              streakCount ?? '0',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
