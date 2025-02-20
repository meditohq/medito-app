import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/root/root_combine_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';

const _carouselHeight = 200.0;
const _dotSize = 8.0;
const _activeDotSize = 12.0;

class BottomRoundedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TopCurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.2); // Start 20% from top
    path.quadraticBezierTo(
      size.width / 2,
      -size.height * 0.1, // Creates upward curve
      size.width,
      size.height * 0.2,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => SplashViewState();
}

class SplashViewState extends ConsumerState<SplashView> {
  var _showAccountButtons = false;
  final _pageController = PageController();
  var _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    var auth = ref.read(authRepositoryProvider);

    try {
      await auth.initializeSupabase();

      if (auth.currentUser != null) {
        await _initializeServices();
        if (!mounted) return;

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RootPageView(
              firstChild: BottomNavigationBarView(),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _showAccountButtons = true;
        });
      }
    } catch (e) {
      dev.log('Failed to initialize Supabase', error: e);
      if (!mounted) return;

      showSnackBar(context, StringConstants.offlineMode);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DownloadsView(),
        ),
      );
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    var auth = ref.read(authRepositoryProvider);

    try {
      await auth.initializeUser();
      await _initializeServices();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OnboardingPagerScreen(),
        ),
      );
    } catch (e) {
      dev.log('Failed to initialize user', error: e);
      if (!mounted) return;

      showSnackBar(context, StringConstants.offlineMode);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DownloadsView(),
        ),
      );
    }
  }

  Future<void> _initializeServices() async {
    HttpApiService().initializeAuth();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await _initializeDioHeaderService();
    ref.read(rootCombineProvider(context));
    _initializeFirebaseMessaging();

    try {
      await StatsManager().initialize();
    } catch (e) {
      dev.log('Stats initialization failed', error: e);
      if (!mounted) return;
      showSnackBar(context, StringConstants.statsInitError);
    }
  }

  Future<void> _initializeDioHeaderService() async {
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    HeaderService(deviceInfo).initialise();
  }

  void _initializeFirebaseMessaging() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firebaseMessaging = ref.read(firebaseMessagingProvider);
      firebaseMessaging.initialize(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) {
          _checkAuthAndInitialize();
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: ClipPath(
                    clipper: TopCurvedClipper(),
                    child: SizedBox(
                      height: 300,
                      child: Image.asset(
                        AssetConstants.splashBackground,
                        fit: BoxFit.cover,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                SvgPicture.asset(
                                  AssetConstants.icLogo,
                                  width: 40,
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'Medito',
                                  style: TextStyle(
                                    color: ColorConstants.white,
                                    fontSize: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Text(
                                  'Meditation Made Simple',
                                  style: TextStyle(
                                    color: ColorConstants.white,
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(
                                  height: _carouselHeight,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: PageView.builder(
                                          controller: _pageController,
                                          onPageChanged: (index) => setState(
                                              () => _currentPageIndex = index),
                                          itemCount: 3,
                                          itemBuilder: (context, index) =>
                                              Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                _getBenefitTitle(index),
                                                style: const TextStyle(
                                                  color: ColorConstants.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.3,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                _getBenefitSubtitle(index),
                                                style: const TextStyle(
                                                  color:
                                                      ColorConstants.graphite,
                                                  fontSize: 16,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          3,
                                          (index) => _buildDotIndicator(index),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 60),
                          if (_showAccountButtons) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.of(context)
                                          .push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SignUpLogInPage(),
                                        ),
                                      )
                                          .then((value) {
                                        if (value == true) {
                                          _checkAuthAndInitialize();
                                        }
                                      }),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            ColorConstants.lightPurple,
                                        foregroundColor: ColorConstants.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        StringConstants
                                            .createAccountLogInButtonText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _handleAnonymousSignIn,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: ColorConstants.lightPurple),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        StringConstants.continueAsGuest,
                                        style: TextStyle(
                                            color: ColorConstants.lightPurple),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getBenefitTitle(int index) {
    switch (index) {
      case 0:
        return 'Free Forever, For Everyone';
      case 1:
        return 'Challenges & Reminders';
      case 2:
        return 'Nonprofit & Ad-Free';
      default:
        return '';
    }
  }

  String _getBenefitSubtitle(int index) {
    switch (index) {
      case 0:
        return 'Explore 100s of hrs of guided sessions, advanced courses, and more. No paywall.';
      case 1:
        return 'Stay motivated daily, track progress, and build lasting habits.';
      case 2:
        return 'Donations keep us going so everyone can access mindfulness—no ads needed.';
      default:
        return '';
    }
  }

  Widget _buildDotIndicator(int index) {
    return Container(
      width: _currentPageIndex == index ? _activeDotSize : _dotSize,
      height: _dotSize,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _currentPageIndex == index
            ? ColorConstants.lightPurple
            : ColorConstants.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
