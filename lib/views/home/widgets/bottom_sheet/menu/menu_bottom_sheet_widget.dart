import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../row_item_widget.dart';

class MenuBottomSheetWidget extends ConsumerWidget {
  const MenuBottomSheetWidget({super.key, required this.homeMenuModel});
  final List<HomeMenuModel> homeMenuModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: bottomSheetBoxDecoration,
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: homeMenuModel
                  .map((element) => RowItemWidget(
                        iconCodePoint: element.icon,
                        title: element.title,
                        hasUnderline: element.id !=
                            homeMenuModel[homeMenuModel.length - 1].id,
                        onTap: () {
                          handleItemPress(context, ref, element);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void handleItemPress(
    BuildContext context,
    WidgetRef ref,
    HomeMenuModel element,
  ) {
    var location = GoRouter.of(context).location;
    _handleTrackEvent(ref, element.id, element.title);
    if (element.type == TypeConstants.LINK) {
      context.push(
        location + RouteConstants.webviewPath,
        extra: {'url': element.path},
      );
    }
    context.push(getPathFromString(
      element.type,
      [element.path.toString().getIdFromPath()],
    ));
  }

  void _handleTrackEvent(WidgetRef ref, int itemId, String itemTitle) {
    var menuItemTappedModel =
        MenuItemTappedModel(itemId: itemId, itemTitle: itemTitle);
    var event = EventsModel(
      name: EventTypes.menuItemTapped,
      payload: menuItemTappedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
