import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../bottom_sheet/debug/debug_bottom_sheet_widget.dart';
import '../bottom_sheet/stats/stats_bottom_sheet_widget.dart';
import '../bottom_sheet/menu/menu_bottom_sheet_widget.dart';

class HomeHeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({
    super.key,
    this.streakCount,
    required this.homeMenuModel,
  });
  final String? streakCount;
  final List<HomeMenuModel> homeMenuModel;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: _logo(context),
      leadingWidth: 24,
      actions: [
        _statsWidget(context, streakCount: streakCount),
        _downloadWidget(context),
        _menuWidget(context),
      ],
      actionsIconTheme: IconThemeData(size: 24),
    );

    // return Padding(
    //   padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
    //   child: Row(
    //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //     children: [
    //       _logo(context),
    //       Row(
    //         children: [
    //           _statsWidget(context, streakCount: streakCount),
    //           width16,
    //           _downloadWidget(context),
    //           width16,
    //           _menuWidget(context),
    //         ],
    //       ),
    //     ],
    //   ),
    // );
  }

  LongPressDetectorWidget _logo(BuildContext context) {
    return LongPressDetectorWidget(
      onLongPress: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: ColorConstants.transparent,
        builder: (BuildContext context) {
          return DebugBottomSheetWidget();
        },
      ),
      duration: Duration(seconds: 3),
      child: SvgPicture.asset(
        AssetConstants.icLogo,
      ),
    );
  }

  IconButton _menuWidget(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.more_vert,
        size: 24,
      ),
      tooltip: 'Menu',
      onPressed: () {
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
    );
  }

  IconButton _downloadWidget(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.downloading,
        size: 24,
      ),
      tooltip: 'Menu',
      onPressed: () => context.push(RouteConstants.collectionPath),
    );
    // return InkWell(
    //   onTap: () => context.push(RouteConstants.collectionPath),
    //   child: SvgPicture.asset(
    //     AssetConstants.icDownload,
    //   ),
    // );
  }

  IconButton _statsWidget(BuildContext context, {String? streakCount}) {
    return IconButton(
      
      icon: const Icon(
        Icons.downloading,
        size: 24,
      ),
      tooltip: 'Menu',
      onPressed: () => context.push(RouteConstants.collectionPath),
    );
    // return InkWell(
    //   onTap: () {
    //     showModalBottomSheet<void>(
    //       context: context,
    //       isScrollControlled: true,
    //       useSafeArea: true,
    //       backgroundColor: ColorConstants.transparent,
    //       builder: (BuildContext context) {
    //         return StatsBottomSheetWidget();
    //       },
    //     );
    //   },
    //   child: Container(
    //     decoration: BoxDecoration(
    //       borderRadius: BorderRadius.circular(14),
    //       border: Border.all(
    //         width: 1,
    //         color: ColorConstants.walterWhite,
    //       ),
    //     ),
    //     padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    //     child: Row(
    //       children: [
    //         const Icon(
    //           Icons.local_fire_department_outlined,
    //           size: 24,
    //           weight: 0.1,
    //           grade: 0,
    //         ),
    //         width4,
    //         Text(
    //           streakCount ?? '0',
    //           style: Theme.of(context).textTheme.titleMedium,
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }

  @override
  Size get preferredSize => Size.fromHeight(56.0);
}
