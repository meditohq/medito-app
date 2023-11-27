import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/widgets/snackbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final retryCounterProvider = StateProvider<int>((ref) => 0);

final appInitializationProvider =
    FutureProvider.family<void, BuildContext>((ref, context) async {
  var _authProvider = ref.read(authProvider);
  try {
    var retryCount = ref.read(retryCounterProvider);
    if (retryCount < 2) {
      _checkInternetConnectivity(context, ref);
    }
    await _authProvider.initializeUser();
    var res = _authProvider.userRes;
    if (res.body != null) {
      var _user = res.body as UserTokenModel;
      _assignNewTokenToDio(ref, _user.token);
      var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
      var data = _setAppOpenedModelData(deviceInfo);

      await ref.read(eventsProvider(event: data.toJson()).future);
      ref.read(retryCounterProvider.notifier).update((state) => 0);
      context.go(RouteConstants.homePath);
    } else {
      _handleRetry(context, ref, false);
    }
  } catch (err) {
    _handleRetry(context, ref, _authProvider.userRes.body != null);
  }
});

void _handleRetry(BuildContext context, Ref ref, bool shouldNavigate) {
  var retryCount = ref.read(retryCounterProvider);
  if (retryCount < 2) {
    _recallProvider(ref, context);
    ref.read(retryCounterProvider.notifier).update((state) => ++state);
  } else {
    if (shouldNavigate) {
      ref.read(retryCounterProvider.notifier).update((state) => 0);
      context.go(RouteConstants.downloadsPath);
    } else {
      _recallProvider(ref, context);
      if (retryCount < 2) {
        showSnackBar(context, StringConstants.timeout);
      }
    }
  }
}

void _recallProvider(Ref<Object?> ref, BuildContext context) {
  Future.delayed(Duration(seconds: 2), () {
    ref.refresh(appInitializationProvider(context));
  });
}

void _checkInternetConnectivity(BuildContext context, Ref ref) {
  var connectivityStatus = ref.read(connectivityStatusProvider);
  if (connectivityStatus == ConnectivityStatus.isDisonnected) {
    showSnackBar(context, StringConstants.connectivityError);
  }
}

void _assignNewTokenToDio(Ref ref, String token) {
  ref
      .read(dioClientProvider)
      .dio
      .options
      .headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
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
