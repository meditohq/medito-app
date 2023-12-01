import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/auth/app_opened_event_provider.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/snackbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'assign_dio_headers_provider.dart';
import 'auth_retry_provider.dart';

final retryCounterProvider = StateProvider<int>((ref) => 0);

final appInitializationProvider =
    FutureProvider.family<void, BuildContext>((ref, context) async {
  var _authProvider = ref.read(authProvider);
  try {
    var retryCount = ref.read(retryCounterProvider);
    if (retryCount < 2) {
      var connectivityStatus = ref.read(connectivityStatusProvider);
      if (connectivityStatus == ConnectivityStatus.isDisonnected) {
        showSnackBar(context, StringConstants.connectivityError);
      }
    }
    await _authProvider.initializeUser();
    var res = _authProvider.userRes;
    if (res.body != null) {
      await ref.read(assignDioHeadersProvider.future);
      await ref.read(appOpenedEventProvider.future);
      ref.read(retryCounterProvider.notifier).update((_) => 0);
      context.go(RouteConstants.homePath);
    } else {
      ref.read(authRetryProvider(
        AuthRetryModel(context: context, isNavigate: false),
      ));
    }
  } catch (err) {
    ref.read(authRetryProvider(
      AuthRetryModel(
        context: context,
        isNavigate: _authProvider.userRes.body != null,
      ),
    ));
  }
});
