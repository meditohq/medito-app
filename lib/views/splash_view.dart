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
import 'package:medito/services/network/header_service.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final waveHeight = 25.0;
    final waveLength = size.width / 3; // Creates 3 full waves
    final initialY = size.height * 0.2;

    path.moveTo(0, initialY);

    // Create continuous waves across full width
    for (double x = 0; x < size.width; x += waveLength) {
      final endX = x + waveLength;
      final controlX = x + waveLength / 2;
      // Alternate wave direction
      final controlY =
          initialY + ((x / waveLength) % 2 < 1 ? -waveHeight : waveHeight);

      path.quadraticBezierTo(
        controlX,
        controlY,
        endX > size.width ? size.width : endX, // Clamp to width
        initialY,
      );
    }

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

class SplashViewState extends ConsumerState<SplashView>
    with WidgetsBindingObserver {
  var _showAccountButtons = false;
  var _isLoading = true;
  final _pageController = PageController();
  var _currentPageIndex = 0;
  var _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialiseApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When app is resumed, try to refresh token silently without showing loader
      _checkAuthStatusOnResume();
    }
  }

  Future<void> _checkAuthStatusOnResume() async {
    try {
      var auth = ref.read(authRepositorySyncProvider);
      if (auth.currentUser != null) {
        var prefs = await SharedPreferences.getInstance();
        var isLoggedIn =
            prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

        if (isLoggedIn) {
          dev.log('[SPLASH] Checking auth status on resume');
          // getToken will only refresh if the current token is expired
          await auth.getToken();
        }
      }
    } catch (e) {
      dev.log('[SPLASH] Auth check failed: $e');
      // We'll let normal API calls handle auth errors if they occur
    }
  }

  Future<void> _initialiseApp() async {
    try {
      dev.log('Initializing Firebase...');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        dev.log('Firebase initialized successfully');
      } else {
        dev.log('Firebase was already initialized');
      }

      await _checkAuthAndInitialize();
    } catch (e, stackTrace) {
      dev.log('Error initializing app', error: e, stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _showAccountButtons = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthAndInitialize() async {
    var auth = ref.read(authRepositorySyncProvider);

    try {
      dev.log('Checking auth state...');
      await auth.initializeUser();

      final currentUser = auth.currentUser;
      final isLoggedIn = await SharedPreferences.getInstance().then((prefs) =>
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false);

      dev.log('Auth state: ${isLoggedIn ? 'logged in' : 'not logged in'}');

      if (isLoggedIn && currentUser != null) {
        dev.log('Initializing services for verified user...');
        await _initializeServices();

        if (!mounted) return;

        dev.log('Navigation to main app...');
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RootPageView(
              firstChild: BottomNavigationBarView(),
            ),
          ),
        );
      } else {
        dev.log('No verified user, showing auth buttons');
        if (!mounted) return;
        setState(() {
          _showAccountButtons = true;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      dev.log('Error in auth check', error: e, stackTrace: stackTrace);
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
    setState(() => _isSigningIn = true);
    var auth = ref.read(authRepositorySyncProvider);

    try {
      await auth.signInAnonymously();
      await _initializeServices();
      ref.read(meRefreshProvider)();

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
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize device info and headers
      final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
      final headerService = HeaderService(deviceInfo);
      await headerService.initialise();

      // Initialize user data
      await ref.read(meProvider.future);

      ref.read(rootCombineProvider(context));
    } catch (e, stackTrace) {
      dev.log('Error initializing services: $e', error: stackTrace);
      showSnackBar(context, StringConstants.appInitError);
    }
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
        backgroundColor: _isLoading ? ColorConstants.black : Colors.transparent,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
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
                            height: 400,
                            child: Image.asset(
                              AssetConstants.placeholder,
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
                                  padding:
                                      const EdgeInsets.only(left: 16, top: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      SvgPicture.asset(
                                        AssetConstants.icLogo,
                                        width: 40,
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                        StringConstants.appName,
                                        style: TextStyle(
                                          color: ColorConstants.white,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(32, 40, 32, 0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const Text(
                                        StringConstants.splashHeadline,
                                        style: TextStyle(
                                          color: ColorConstants.white,
                                          fontSize: 40,
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
                                                onPageChanged: (index) =>
                                                    setState(() =>
                                                        _currentPageIndex =
                                                            index),
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
                                                        color: ColorConstants
                                                            .white,
                                                        fontSize: 28,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      _getBenefitSubtitle(
                                                          index),
                                                      style: const TextStyle(
                                                        color: ColorConstants
                                                            .graphite,
                                                        fontSize: 20,
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
                                                (index) =>
                                                    _buildDotIndicator(index),
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
                                    padding: const EdgeInsets.fromLTRB(
                                        32, 0, 32, 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context)
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
                                              foregroundColor:
                                                  ColorConstants.white,
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
                                            onPressed: _isSigningIn
                                                ? null
                                                : _handleAnonymousSignIn,
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  ColorConstants.black,
                                              side: const BorderSide(
                                                  color: ColorConstants
                                                      .lightPurple),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: _isSigningIn
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: ColorConstants
                                                          .lightPurple,
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Text(
                                                    StringConstants
                                                        .continueAsGuest,
                                                    style: TextStyle(
                                                        color: ColorConstants
                                                            .lightPurple),
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
        return StringConstants.splashBenefit1Title;
      case 1:
        return StringConstants.splashBenefit2Title;
      case 2:
        return StringConstants.splashBenefit3Title;
      default:
        return '';
    }
  }

  String _getBenefitSubtitle(int index) {
    switch (index) {
      case 0:
        return StringConstants.splashBenefit1Subtitle;
      case 1:
        return StringConstants.splashBenefit2Subtitle;
      case 2:
        return StringConstants.splashBenefit3Subtitle;
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
