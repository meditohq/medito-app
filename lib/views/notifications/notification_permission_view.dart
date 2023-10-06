import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionView extends ConsumerWidget {
  const NotificationPermissionView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    var size = MediaQuery.of(context).size;
    var bottom = getBottomPadding(context);

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              AssetConstants.dalleNotifications,
              height: size.height * 0.45,
              width: size.width,
              fit: BoxFit.cover,
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      StringConstants.allowNotificationsTitle,
                      style: textTheme.headlineMedium?.copyWith(
                        color: ColorConstants.walterWhite,
                        fontFamily: ClashDisplay,
                        height: 1.2,
                        fontSize: 24,
                      ),
                    ),
                    height8,
                    Text(
                      StringConstants.allowNotificationsDesc,
                      style: textTheme.bodyMedium?.copyWith(
                        color: ColorConstants.walterWhite,
                        fontFamily: ClashDisplay,
                        height: 1.6,
                        fontSize: 16,
                      ),
                    ),
                    height8,
                    Spacer(),
                    SizedBox(
                      width: size.width,
                      child: LoadingButtonWidget(
                        onPressed: () => _allowNotification(context, ref),
                        btnText: StringConstants.allowNotifications,
                        bgColor: ColorConstants.walterWhite,
                        fontWeight: FontWeight.w600,
                        textColor: ColorConstants.greyIsTheNewGrey,
                      ),
                    ),
                    height8,
                    SizedBox(
                      width: size.width,
                      child: LoadingButtonWidget(
                        onPressed: () => _handleNotNow(context),
                        btnText: StringConstants.notNow,
                        bgColor: ColorConstants.onyx,
                        fontWeight: FontWeight.w600,
                        textColor: ColorConstants.walterWhite,
                      ),
                    ),
                    height8,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _allowNotification(BuildContext context, WidgetRef ref) async {
    var status = await requestPermission();
    if (status.isPermanentlyDenied) {
      await ref
            .read(sharedPreferencesProvider).setBool(
        SharedPreferenceConstants.notificationPermission,
        false,
      );
    }
    context.pop();
  }

  void _handleNotNow(BuildContext context) {
    context.pop();
  }
}
