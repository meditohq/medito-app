import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
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
      initializeUserToken();
    });
    super.initState();
  }

  void initializeUserToken() {
    var auth = ref.read(authProvider);
    var authToken = ref.read(authTokenProvider.notifier);
    authToken.initializeUserToken().then((_) {
      var userTokenModel = ref.read(authTokenProvider).asData?.value;
      assignNewTokenToDio('Bearer ${userTokenModel?.token}');
      initializeAudioPlayer('Bearer ${userTokenModel?.token}');
      auth.getUserEmailFromSharedPref().then((_) {
        if (auth.userEmail != null) {
          context.go(RouteConstants.homePath);
        } else {
          context.go(RouteConstants.joinIntroPath);
        }
      });
    }).catchError((e) {
      initializeUserToken();
    });
  }

  void assignNewTokenToDio(String token) {
    ref
        .read(dioClientProvider)
        .dio
        .options
        .headers[HttpHeaders.authorizationHeader] = token;
  }

  void initializeAudioPlayer(String token) {
    ref.read(audioPlayerNotifierProvider).setContentToken(
          token,
        );
    ref.read(playerProvider.notifier).getCurrentlyPlayingSession();
    ref.read(audioPlayerNotifierProvider).initAudioHandler();
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
