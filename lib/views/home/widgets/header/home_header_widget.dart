import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
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
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _logo(context),
            Row(
              children: [
                _statsWidget(context, ref),
                _downloadWidget(context),
                _menuWidget(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo(BuildContext context) {
    return LongPressDetectorWidget(
      onLongPress: () {
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          backgroundColor: ColorConstants.onyx,
          builder: (BuildContext context) {
            return DebugBottomSheetWidget();
          },
        );
      },
      duration: Duration(seconds: 1, milliseconds: 500),
      child: IconButton(
        onPressed: () => {},
        icon: SvgPicture.asset(
          AssetConstants.icLogo,
          width: 32,
        ),
      ),
    );
  }

  IconButton _menuWidget(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.more_vert,
        size: 24,
      ),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          backgroundColor: ColorConstants.onyx,
          builder: (BuildContext context) {
            return MenuBottomSheetWidget(
              homeMenuModel: homeMenuModel,
            );
          },
        );
      },
    );
  }

  Transform _downloadWidget(BuildContext context) {
    return Transform.translate(
      offset: Offset(5, 0),
      child: IconButton(
        icon: const Icon(
          Icons.downloading,
          size: 24,
        ),
        onPressed: () => context.push(RouteConstants.collectionPath),
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 2,
            color: ColorConstants.walterWhite,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 0.6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
            ),
            width4,
            Text(
              streakCount,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(56.0);
}
