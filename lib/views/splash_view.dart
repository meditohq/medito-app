import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authInitTokenProvider.notifier).initializeToken();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authInitTokenProvider, (_, next) {
      if (next.hasValue) {
        if (next.value == AUTH_INIT_STATUS.TOKEN_INIT_COMPLETED) {
          _handleAppOpenedEvent();
          ref.read(authInitTokenProvider.notifier).initializeUser();
        } else if (next.value == AUTH_INIT_STATUS.IS_USER_PRESENT) {
          context.go(RouteConstants.homePath);
        } else if (next.value == AUTH_INIT_STATUS.IS_USER_NOT_PRESENT) {
          context.go(RouteConstants.joinIntroPath);
        }
      } else if (next.hasError) {
        var retryCount = ref.read(authInitTokenProvider.notifier).retryCount;
        if (retryCount < 4) {
          ref.read(authInitTokenProvider.notifier).initializeToken();
        }
        showSnackBar(context, next.error.toString());
      }
    });

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: Center(
        child: SvgPicture.asset(
          AssetConstants.icLogo,
          width: 160,
        ),
      ),
    );
  }

  void _handleAppOpenedEvent() {
    var deviceAndAppInfo = ref.read(deviceAndAppInfoProvider.notifier);
    deviceAndAppInfo.getDeviceAndAppInfo().then((_) {
      var val = ref.read(deviceAndAppInfoProvider).asData?.value;
      var appOpenedModel = AppOpenedModel(
        deviceOs: val?.os ?? '',
        deviceLanguage: val?.languageCode ?? '',
        deviceModel: val?.model ?? '',
        buildNumber: val?.buildNumber ?? '',
        appVersion: val?.appVersion ?? '',
      );
      var event = EventsModel(
        name: EventTypes.appOpened,
        payload: appOpenedModel.toJson(),
      );
      ref.read(eventsProvider(event: event.toJson()));
    });
  }
}
