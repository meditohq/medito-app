import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
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
  var retryCounter = 0;
  final maxRetryCount = 2;

  @override
  void initState() {
    initializeUser();

    super.initState();
  }

  void initializeUser() async {
    try {
      var response = await ref.read(initializeUserProvider.future);
      if (response) {
        context.go(RouteConstants.homePath);
      } else {
        retryInitializeUser();
      }
    } catch (e) {
      retryInitializeUser();
    }
  }

  void retryInitializeUser() {
    if (retryCounter < maxRetryCount) {
      Future.delayed(Duration(seconds: 2), () {
        incrementCounter();
        initializeUser();
      });
    } else {
      showSnackBar(context, StringConstants.timeout);
      context.go(RouteConstants.downloadsPath);
    }
  }

  void resetCounter() => retryCounter = 0;
  void incrementCounter() => retryCounter += 1;

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityStatusProvider, (previous, next) {
      var isDisconnected = next == ConnectivityStatus.isDisonnected;
      if (isDisconnected) {
        showSnackBar(context, StringConstants.connectivityError);
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
}
