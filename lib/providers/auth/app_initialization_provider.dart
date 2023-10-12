import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final retryCounterProvider = StateProvider<int>((ref) => 0);

final appInitializationProvider =
    FutureProvider.family<void, BuildContext>((ref, context) async {
  try {
    var _authProvider = ref.read(authProvider);
    await _authProvider.initializeUser();
    var _user = _authProvider.userRes.body as UserTokenModel;
    _assignNewTokenToDioAndAudioPlayer(ref, _user.token);
    var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    var data = _setAppOpenedModelData(deviceInfo);

    await ref.read(eventsProvider(event: data.toJson()).future);
    context.go(RouteConstants.homePath);
  } catch (err) {
    print(err);
    _handleRetry(context, ref);
  }
});

void _handleRetry(BuildContext context, Ref ref) {
  var retryCount = ref.read(retryCounterProvider);
  if (retryCount < 2) {
    Future.delayed(Duration(seconds: 2), () {
      ref.refresh(appInitializationProvider(context));
    });
    ref.read(retryCounterProvider.notifier).update((state) => ++state);
  } else {
    ref.read(retryCounterProvider.notifier).update((state) => 0);
    context.go(RouteConstants.downloadsPath);
  }
}

void _assignNewTokenToDioAndAudioPlayer(Ref ref, String token) {
  ref
      .read(dioClientProvider)
      .dio
      .options
      .headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
  ref.read(audioPlayerNotifierProvider).setContentToken('Bearer $token');
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
