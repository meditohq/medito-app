import 'package:Medito/components/components.dart';
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
      ref.read(authInitTokenProvider.notifier).initToken();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authInitTokenProvider, (_, next) {
      if (next.hasValue) {
        if (next.value != false) {
          context.go(RouteConstants.homePath);
        } else {
          context.go(RouteConstants.joinIntroPath);
        }
      } else if (next.hasError) {
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
}
