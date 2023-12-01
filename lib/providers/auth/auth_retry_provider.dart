import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_initialization_provider.dart';

final authRetryProvider =
    StateProvider.family<void, AuthRetryModel>((ref, data) {
  var retryCount = ref.watch(retryCounterProvider);

  if (retryCount < 2) {
    _recallProvider(ref, data.context);
    ref.read(retryCounterProvider.notifier).update((state) => ++state);
  } else {
    if (data.isNavigate) {
      try {
        data.context.go(RouteConstants.downloadsPath);
      } catch (e) {
        print(e);
      }
    } else {
      _recallProvider(ref, data.context);

      if (retryCount < 2) {
        showSnackBar(data.context, StringConstants.timeout);
      }
    }
  }
});

void _recallProvider(Ref<Object?> ref, BuildContext context) {
  Future.delayed(
    Duration(seconds: 2),
    () => ref.refresh(appInitializationProvider(context)),
  );
}

//ignore: prefer-match-file-name
class AuthRetryModel {
  BuildContext context;
  bool isNavigate;
  AuthRetryModel({required this.context, required this.isNavigate});
}
