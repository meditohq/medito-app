import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionView extends ConsumerStatefulWidget {
  const NotificationPermissionView({super.key});

  @override
  ConsumerState<NotificationPermissionView> createState() =>
      _NotificationPermissionViewState();
}

class _NotificationPermissionViewState
    extends ConsumerState<NotificationPermissionView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      var status =
          await ref.refresh(notificationPermissionStatusProvider.future);
      if (status == AuthorizationStatus.authorized) {
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var status = ref.watch(notificationPermissionStatusProvider);
    var textTheme = Theme.of(context).textTheme;
    var size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    AssetConstants.dalleNotifications,
                    height: size.height * 0.45,
                    width: size.width,
                    fit: BoxFit.cover,
                  ),
                  _buildTitleAndDesc(textTheme),
                ],
              ),
            ),
          ),
          _buildBottomActionButttons(status, size),
        ],
      ),
    );
  }

  Padding _buildBottomActionButttons(
    AsyncValue<AuthorizationStatus> status,
    Size size,
  ) {
    return Padding(
      padding: const EdgeInsets.all(padding16),
      child: SafeArea(
        child: status.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (data) {
            return data == AuthorizationStatus.denied
                ? _buildOpenNotificationSettingsButton(size)
                : _buildAllowNotificationAndNotNowButtons(size);
          },
          error: (err, stack) => MeditoErrorWidget(
            message: err.toString(),
            onTap: () => ref.refresh(notificationPermissionStatusProvider),
            isLoading: status.isLoading,
          ),
          loading: () => const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Padding _buildTitleAndDesc(TextTheme textTheme) {
    const padding = EdgeInsets.only(
      top: 24,
      bottom: padding16,
      left: padding16,
      right: padding16,
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StringConstants.allowNotificationsTitle,
            style: textTheme.headlineMedium?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: SourceSerif,
              height: 1.2,
              fontSize: 24,
            ),
          ),
          height8,
          Text(
            StringConstants.allowNotificationsDesc,
            style: _textStyle(textTheme),
          ),
          height16,
          Text(
            StringConstants.notificationTurnOnMessage,
            style: _textStyle(textTheme),
          ),
          height16,
        ],
      ),
    );
  }

  TextStyle? _textStyle(TextTheme textTheme) {
    return textTheme.bodyMedium?.copyWith(
      color: ColorConstants.walterWhite,
      fontFamily: DmSans,
      height: 1.4,
      fontSize: 16,
    );
  }

  Column _buildAllowNotificationAndNotNowButtons(
    Size size,
  ) {
    return Column(
      children: [
        SizedBox(
          width: size.width,
          height: 48,
          child: LoadingButtonWidget(
            onPressed: () => _allowNotification(),
            btnText: StringConstants.allowNotifications,
            bgColor: ColorConstants.walterWhite,
            textColor: ColorConstants.onyx,
          ),
        ),
        height8,
        SizedBox(
          width: size.width,
          height: 48,
          child: LoadingButtonWidget(
            onPressed: () => _handleNotNow(),
            btnText: StringConstants.notNow,
            bgColor: ColorConstants.onyx,
            textColor: ColorConstants.walterWhite,
          ),
        ),
      ],
    );
  }

  SizedBox _buildOpenNotificationSettingsButton(
    Size size,
  ) {
    return SizedBox(
      width: size.width,
      height: 48,
      child: LoadingButtonWidget(
        onPressed: () => _handleOpenSettings(),
        btnText: StringConstants.openSettings,
        bgColor: ColorConstants.walterWhite,
        textColor: ColorConstants.onyx,
      ),
    );
  }

  void _allowNotification() async {
    var status = await requestPermission();
    if (status.isPermanentlyDenied) {
      await ref.read(sharedPreferencesProvider).setBool(
            SharedPreferenceConstants.notificationPermission,
            false,
          );
    }
    context.pop();
  }

  void _handleNotNow() async {
    await ref.read(updateNotificationPermissionCountProvider.future);
    ref.read(getNotificationPermissionCountProvider);
    context.pop();
  }

  void _handleOpenSettings() async {
    await AppSettings.openAppSettings(
      type: AppSettingsType.notification,
      asAnotherTask: true,
    );
  }
}
