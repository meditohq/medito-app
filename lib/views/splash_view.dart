import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  var _isConnected = true;
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    initializeUser();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
        if (!_isConnected) {
          showSnackBar(context, StringConstants.connectivityError);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void initializeUser() async {
    var response = await ref.read(userInitializationProvider.future);
    if (response == UserInitializationStatus.successful) {
      context.go(RouteConstants.bottomNavbarPath);
    } else if (response == UserInitializationStatus.error) {
      showSnackBar(context, StringConstants.timeout);
      context.go(RouteConstants.downloadsPath);
    } else if (response == UserInitializationStatus.retry) {
      ref.invalidate(userInitializationProvider);
      initializeUser();
    }
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
}
