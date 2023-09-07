import 'dart:io';

import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
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
  int retryCount = 0;
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleUserInitialization();
    });
    super.initState();
  }

  void _handleUserInitialization() {
    var _authProvider = ref.read(authProvider);
    _authProvider.initializeUser().then((_) {
      var _user = _authProvider.userRes.body as UserTokenModel;
      _assignNewTokenToDioAndAudioPlayer(_user.token);
      ref.read(deviceAndAppInfoProvider.future).then((value) {
        var data = _setAppOpenedModelData(value);
        var appOpenedEventRes =
            ref.read(eventsProvider(event: data.toJson()).future);
        appOpenedEventRes.then((value) {
          if (_user.email != null) {
            context.go(RouteConstants.homePath);
          } else {
            context.go(RouteConstants.joinIntroPath);
          }
        }).catchError((err) {
          _handleRetry(err.toString());
        });
      });
    }).catchError((err) {
      _handleRetry(err.toString());
    });
  }

  void _handleRetry(String err) {
    if (retryCount < 4) {
      Future.delayed(Duration(seconds: 2), () {
        _handleUserInitialization();
      });
      showSnackBar(context, err);
      retryCount = ++retryCount;
    } else {
      showSnackBar(context, StringConstants.timeout);
    }
  }

  void _assignNewTokenToDioAndAudioPlayer(String token) {
    ref
        .read(dioClientProvider)
        .dio
        .options
        .headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    ref.read(audioPlayerNotifierProvider).setContentToken('Bearer $token');
  }

  @override
  Widget build(BuildContext context) {
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

  EventsModel _setAppOpenedModelData(DeviceAndAppInfoModel val) {
    var appOpenedModel = AppOpenedModel(
      deviceOs: val.os,
      deviceLanguage: val.languageCode,
      deviceModel: val.model,
      buildNumber: val.buildNumber,
      appVersion: val.appVersion,
    );
    var event = EventsModel(
      name: EventTypes.appOpened,
      payload: appOpenedModel.toJson(),
    );

    return event;
  }
}
