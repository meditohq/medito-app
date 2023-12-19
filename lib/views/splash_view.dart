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
  @override
  void initState() {
    initializeUser();
    super.initState();
  }

  void initializeUser() async {
    var response = await ref.read(userInitializationProvider.future);
    if (response == UserInitializationStatus.successful) {
      context.go(RouteConstants.homePath);
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
    ref.listen(connectivityStatusProvider, (previous, next) {
      var isDisconnected = next == ConnectivityStatus.isDisconnected;
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
