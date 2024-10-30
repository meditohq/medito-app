import 'package:medito/constants/constants.dart';
import 'package:medito/main.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/utils/fade_page_route.dart';
import 'package:medito/widgets/snackbar_widget.dart';

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
      await ref.read(authRepositoryProvider).initializeUser();
      await StatsManager().sync();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        FadePageRoute(
          builder: (context) => const RootPageView(
            firstChild: BottomNavigationBarView(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showSnackBar(context, StringConstants.offlineMode);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DownloadsView()),
      );
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
