import 'package:Medito/constants/constants.dart';
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
    Future.delayed(Duration(seconds: 2), () {
      context.go(RouteConstants.homePath);
    });
    super.initState();
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
