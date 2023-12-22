import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bottom_sheet/debug/debug_bottom_sheet_widget.dart';
import '../bottom_sheet/menu/menu_bottom_sheet_widget.dart';

class HomeHeaderWidget extends ConsumerWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({
    super.key,
    required this.homeMenuModel,
  });

  final List<HomeMenuModel> homeMenuModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _welcomeWidget(context),
          Row(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 34), // Add top padding
                child: _menuWidget(context),
              ),
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
                fontWeight: FontWeight.w700,
                fontFamily: SourceSerif,
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

  @override
  Size get preferredSize => Size.fromHeight(72.0);
}
