import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../row_item_widget.dart';

class MenuBottomSheetWidget extends ConsumerWidget {
  const MenuBottomSheetWidget({super.key, required this.homeMenuModel});

  final List<HomeMenuModel> homeMenuModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var status = ref.watch(notificationPermissionStatusProvider);

    return status.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      data: (data) {
        var isNotificationMenuVisible = true;

        if (data == AuthorizationStatus.authorized ||
            data == AuthorizationStatus.provisional) {
          isNotificationMenuVisible = false;
        }

        return _buildMain(context, isNotificationMenuVisible, ref);
      },
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(notificationPermissionStatusProvider),
        isLoading: status.isLoading,
      ),
      loading: () => const CircularProgressIndicator(),
    );
  }

  Container _buildMain(
    BuildContext context,
    bool isNotificationMenuVisible,
    WidgetRef ref,
  ) {
    return Container(
      decoration: bottomSheetBoxDecoration,
      padding: EdgeInsets.only(bottom: getBottomPadding(context)),
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
              children: homeMenuModel.map((element) {
                var isNotificationPath = element.path ==
                    RouteConstants.notificationPermissionPath.sanitisePath();

                if (!isNotificationMenuVisible && isNotificationPath) {
                  return SizedBox();
                }

                return RowItemWidget(
                  enableInteractiveSelection: false,
                  iconCodePoint: element.icon,
                  title: element.title,
                  hasUnderline: element.id != homeMenuModel.last.id,
                  onTap: () {
                    handleItemPress(context, ref, element);
                  },
                );
              }).toList(),
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
  ) async {
    _handleTrackEvent(ref, element.id, element.title);
    Navigator.pop(context);
    await handleNavigation(
      context: context,
      element.type,
      [element.path.toString().getIdFromPath(), element.path],
      ref: ref,
    );
  }

  void _handleTrackEvent(WidgetRef ref, String itemId, String itemTitle) {
    var menuItemTappedModel =
        MenuItemTappedModel(itemId: itemId, itemTitle: itemTitle);
    var event = EventsModel(
      name: EventTypes.menuItemTapped,
      payload: menuItemTappedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
