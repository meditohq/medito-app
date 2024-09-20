import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/assign_dio_headers.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../services/notifications/firebase_notifications_service.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    super.initState();
    _initializeUser();
    _initializeFirebaseMessaging();
  }

  void _initializeUser() async {
    try {
      var authRepo = ref.read(authRepositoryProvider);
      var token = await authRepo.initializeUser();
      var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
      AssignDioHeaders(token, deviceInfo).assign();
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => const RootPageView(
          firstChild: BottomNavigationBarView(),
        ),
      ));
    } catch (e) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => const DownloadsView(),
      ));
      return;
    }
  }

  void _initializeFirebaseMessaging() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firebaseMessaging = ref.read(firebaseMessagingProvider);
      firebaseMessaging.initialize(context, ref);
    });
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
