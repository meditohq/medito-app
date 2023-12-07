import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../bottom_sheet/debug/debug_bottom_sheet_widget.dart';
import '../bottom_sheet/stats/stats_bottom_sheet_widget.dart';
import '../bottom_sheet/menu/menu_bottom_sheet_widget.dart';

class HomeHeaderWidget extends ConsumerWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({
    super.key,
    required this.homeMenuModel,
    this.miniStatsModel,
  });

  final List<HomeMenuModel> homeMenuModel;
  final MiniStatsModel? miniStatsModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _welcomeWidget(context),
          Row(
            children: [
              // _statsWidget(context, ref),
              // _downloadWidget(context),
              _menuWidget(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _welcomeWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20.0),
      child: LongPressDetectorWidget(
        onLongPress: () {
          showModalBottomSheet<void>(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.0),
                topRight: Radius.circular(14.0),
              ),
            ),
            useRootNavigator: true,
            backgroundColor: ColorConstants.onyx,
            builder: (BuildContext context) {
              return DebugBottomSheetWidget();
            },
          );
        },
        duration: Duration(milliseconds: 500),
        child: Text(
          StringConstants.welcome,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ColorConstants.walterWhite,
                height: 0,
                fontSize: 28,
                fontFamily: DmSerif,
              ),
        ),
      ),
    );
  }

  Material _menuWidget(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: IconButton(
        icon: const Icon(
          Icons.more_vert,
          size: 24,
        ),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.0),
                topRight: Radius.circular(14.0),
              ),
            ),
            useRootNavigator: true,
            backgroundColor: ColorConstants.onyx,
            builder: (BuildContext context) {
              return MenuBottomSheetWidget(
                homeMenuModel: homeMenuModel,
              );
            },
          );
        },
      ),
    );
  }

  Transform _downloadWidget(BuildContext context) {
    return Transform.translate(
      offset: Offset(5, 0),
      child: Material(
        type: MaterialType.transparency,
        shape: CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: IconButton(
          icon: const Icon(
            Icons.downloading,
            size: 24,
          ),
          onPressed: () => context.push(RouteConstants.downloadsPath),
        ),
      ),
    );
  }

  InkWell _statsWidget(BuildContext context, WidgetRef ref) {
    var icon = miniStatsModel?.icon != null
        ? IconData(
            formatIcon(miniStatsModel!.icon),
            fontFamily: 'MaterialIcons',
          )
        : Icons.local_fire_department_outlined;
    var streakCount = miniStatsModel?.value.toString() ?? '0';

    return InkWell(
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onTap: () {
        ref.invalidate(remoteStatsProvider);
        ref.read(remoteStatsProvider);
        showModalBottomSheet<void>(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14.0),
              topRight: Radius.circular(14.0),
            ),
          ),
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: ColorConstants.onyx,
          builder: (BuildContext context) {
            return StatsBottomSheetWidget();
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: ColorConstants.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 2,
            color: ColorConstants.walterWhite,
          ),
        ),
        padding: EdgeInsets.only(left: 6, right: 6, top: 1, bottom: 1),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: ColorConstants.walterWhite,
            ),
            width2,
            Text(
              streakCount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ColorConstants.walterWhite,
                    height: 0,
                    fontSize: 14,
                    fontFamily: DmMono,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(56.0);
}
