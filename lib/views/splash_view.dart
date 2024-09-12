import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    super.initState();
    initializeUser();
  }

  void initializeUser() async {
    var response = await ref.read(userInitializationProvider.future);
    
    if (response == UserInitializationStatus.successful) {
      await FirebaseAnalytics.instance
          .logEvent(name: 'user_initialization_successful');
      
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => RootPageView(
          firstChild: BottomNavigationBarView(),
        ),
      ));
    } else if (response == UserInitializationStatus.error) {
      await FirebaseAnalytics.instance
          .logEvent(name: 'user_initialization_error');

      showSnackBar(context, StringConstants.timeout);
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => DownloadsView(),
      ));
    } else if (response == UserInitializationStatus.retry) {
      await FirebaseAnalytics.instance
          .logEvent(name: 'user_initialization_retry');
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
