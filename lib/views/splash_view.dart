// ignore_for_file: use_build_context_synchronously

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/root/root_combine_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/tiktok_analytics_service.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _carouselHeight = 200.0;
const _dotSize = 8.0;
const _activeDotSize = 12.0;

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  // Static route name for navigation
  static const routeName = 'SplashView';

  @override
  SplashViewState createState() => SplashViewState();
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
        AppLogger.d(
            'SPLASH', 'Current user before resume check: ${auth.currentUser}');

        if (await auth.isLoggedIn()) {
          AppLogger.d('SPLASH', 'Checking auth status on resume');
          // getToken will only refresh if the current token is expired
          try {
            await auth.getToken();
            AppLogger.i('SPLASH',
                'Token refresh successful on resume, current user: ${auth.currentUser}');
            AppLogger.i(
                'SPLASH', 'User email after resume: ${auth.getUserEmail()}');
          } catch (e, stackTrace) {
            AppLogger.e(
                'SPLASH', 'Token refresh failed on resume', e, stackTrace);
            // Auth repository handles whether to force logout or not for different error types
          }
        }
      } else {
        AppLogger.w('SPLASH', 'No current user during resume check');
      }
    } catch (e, stackTrace) {
      AppLogger.e('SPLASH', 'Auth check on resume failed', e, stackTrace);
      // We'll let normal API calls handle auth errors if they occur
    }
  }

  Future<void> _initialiseApp() async {
    try {
      // First initialize Firebase
      await _initializeFirebase();

      // Then initialize Firebase Analytics separately
      await _initializeAnalytics();

      // Continue with app initialization
      await _checkAuthAndInitialize();
    } catch (e, stackTrace) {
      AppLogger.e('SPLASH', 'Error initializing app', e, stackTrace);
      CrashlyticsService().recordError(
        e,
        stackTrace,
        reason: 'SplashView: Error during initialization',
      );
      if (!mounted) return;

      setState(() {
        _showAccountButtons = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeFirebase() async {
    AppLogger.i('SPLASH', 'Initializing Firebase...');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.i('SPLASH', 'Firebase initialized successfully');
    } else {
      AppLogger.i('SPLASH', 'Firebase was already initialized');
    }
  }

  Future<void> _initializeAnalytics() async {
    try {
      // Initialize Firebase Analytics with consent enabled using consent mode v2
      // Don't request ATT permission yet - we'll do that later for better UX
      await FirebaseAnalyticsService()
          .initialize(requestAttPermissionImmediately: false);
      AppLogger.i(
          'SPLASH', 'Firebase Analytics initialized with consent mode v2');

      // Initialize TikTok Analytics and log first open once
      await TikTokAnalyticsService()
          .initialize(requestAttPermissionImmediately: false);
      await TikTokAnalyticsService().logAppFirstOpenOnce();
    } catch (e, stackTrace) {
      // Log the error but don't prevent app startup
      AppLogger.e(
          'SPLASH', 'Error initializing Firebase Analytics', e, stackTrace);
      CrashlyticsService().recordError(
        e,
        stackTrace,
        reason: 'SplashView: Error initializing Firebase Analytics',
      );
    }
  }

  Future<void> _checkAuthAndInitialize() async {
    var auth = ref.read(authRepositorySyncProvider);

    try {
      AppLogger.i('SPLASH', 'Starting auth initialization');
      await auth.initializeUser();
      AppLogger.i(
          'SPLASH', 'Auth initialized, current user: ${auth.currentUser}');
      AppLogger.i('SPLASH', 'User email from auth: ${auth.getUserEmail()}');

      final currentUser = auth.currentUser;
      final isLoggedIn = await auth.isLoggedIn();
      AppLogger.i('SPLASH',
          'Auth state: ${isLoggedIn ? 'logged in' : 'not logged in'}, has email: ${currentUser?.email != null}');

      if (isLoggedIn && currentUser != null) {
        AppLogger.i('SPLASH', 'Initializing services for verified user...');
        await _initializeServices();
        AppLogger.i('SPLASH', 'Services initialized');

        if (!mounted) return;

        AppLogger.i('SPLASH', 'Navigation to main app...');
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RootPageView(
              firstChild: BottomNavigationBarView(),
            ),
          ),
        );
      } else {
        AppLogger.i('SPLASH', 'No verified user, showing auth buttons');
        if (!mounted) return;
        setState(() {
          _showAccountButtons = true;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e(
          'SPLASH',
          'Error in _checkAuthAndInitialize, navigating to DownloadsView',
          e,
          stackTrace);
      CrashlyticsService().recordError(
        e,
        stackTrace,
        reason:
            'SplashView: Error in _checkAuthAndInitialize, navigating to DownloadsView',
      );
      if (!mounted) return;

      setState(() {
        _showAccountButtons = true;
        _isLoading = false;
      });

      showSnackBar(context, AppLocalizations.of(context)!.offlineMode);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DownloadsView(isRoot: false),
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
    } on EmailExistsError catch (_) {
      if (!mounted) return;

      final shouldUseExistingAccount = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.emailExistsDialogTitle,
          ),
          content: Text(
            AppLocalizations.of(context)!.emailExistsDialogMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                AppLocalizations.of(context)!.emailExistsContinueNewAccount,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorConstants.brightSky,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                AppLocalizations.of(context)!.emailExistsSignInWithEmail,
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (shouldUseExistingAccount == true) {
        await Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => const SignUpLogInPage(),
          ),
        )
            .then((value) {
          if (value == true) {
            _checkAuthAndInitialize();
          }
        });
      } else {
        // User wants to continue with a new account
        // Clear the stored client ID so a new one will be generated
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(SharedPreferenceConstants.userId);
        // Try signing in anonymously again
        await _handleAnonymousSignIn();
      }
    } catch (e, stackTrace) {
      AppLogger.e('SPLASH', 'Failed to initialize user (anonymous sign-in)', e,
          stackTrace);
      CrashlyticsService().recordError(
        e,
        stackTrace,
        reason: 'SplashView: Failed to initialize user (anonymous sign-in)',
      );
      if (!mounted) return;

      showSnackBar(context, AppLocalizations.of(context)!.offlineMode);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DownloadsView(isRoot: true),
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
      AppLogger.i('SPLASH', 'Starting services initialization');

      // Initialize device info and headers (which now includes user's language preference)
      final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
      final headerService = HeaderService(deviceInfo);
      await headerService.initialise();
      AppLogger.i('SPLASH', 'Header service initialized');

      // Initialize user data
      try {
        AppLogger.i('SPLASH', 'Fetching user data...');
        final userData = await ref.read(meProvider.future);
        AppLogger.d('SPLASH', 'User data fetched: ${userData.toString()}');
      } catch (e, stackTrace) {
        AppLogger.e('SPLASH', 'Error fetching user data', e, stackTrace);
        CrashlyticsService().recordError(
          e,
          stackTrace,
          reason: 'SplashView: Error fetching user data in _initializeServices',
        );
      }

      ref.read(rootCombineProvider(context));
      AppLogger.i('SPLASH', 'Services initialization complete');
    } catch (e, stackTrace) {
      AppLogger.e('SPLASH', 'Error initializing services', e, stackTrace);
      CrashlyticsService().recordError(
        e,
        stackTrace,
        reason: 'SplashView: Error initializing services',
      );
      showSnackBar(context, AppLocalizations.of(context)!.appInitError);
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
        backgroundColor: _isLoading
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.transparent,
        body: _isLoading
            ? Center(
                child: SvgPicture.asset(
                  AssetConstants.icLogo,
                  colorFilter: ColorFilter.mode(ColorConstants.lightPurple, BlendMode.srcIn),
                  width: 168,
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: 500,
                          child: Image.asset(
                            AssetConstants.splashBackground,
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.bottomCenter,
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
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: SvgPicture.asset(
                                          AssetConstants.icLogo,
                                          width: 40,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        AppLocalizations.of(context)!.appName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                              fontSize: 24,
                                              color: Colors.white,
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
                                      Text(
                                        AppLocalizations.of(context)!
                                            .splashHeadline,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              height: 1.2,
                                              color: Colors.white,
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
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displayLarge
                                                          ?.copyWith(
                                                            fontSize: 28,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            height: 1.3,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      _getBenefitSubtitle(
                                                          index),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontSize: 20,
                                                            height: 1.4,
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.9),
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
                                            onPressed: () async {
                                              // Log analytics event for signup button tap
                                              await FirebaseAnalyticsService()
                                                  .logEvent(
                                                name: FirebaseAnalyticsService
                                                    .eventOnboardingSplashscreenSignupTap,
                                              );

                                              await Navigator.of(context)
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
                                              });
                                            },
                                            child: Text(
                                              AppLocalizations.of(context)!
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
                                                : () async {
                                                    // Log analytics event for continue button tap
                                                    await FirebaseAnalyticsService()
                                                        .logEvent(
                                                      name: FirebaseAnalyticsService
                                                          .eventOnboardingSplashscreenContinueTap,
                                                    );

                                                    await _handleAnonymousSignIn();
                                                  },
                                            child: _isSigningIn
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .continueAsGuest,
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
        return AppLocalizations.of(context)!.splashBenefit1Title;
      case 1:
        return AppLocalizations.of(context)!.splashBenefit2Title;
      case 2:
        return AppLocalizations.of(context)!.splashBenefit3Title;
      default:
        return '';
    }
  }

  String _getBenefitSubtitle(int index) {
    switch (index) {
      case 0:
        return AppLocalizations.of(context)!.splashBenefit1Subtitle;
      case 1:
        return AppLocalizations.of(context)!.splashBenefit2Subtitle;
      case 2:
        return AppLocalizations.of(context)!.splashBenefit3Subtitle;
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
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        shape: BoxShape.circle,
      ),
    );
  }

  // Public method that can be called from outside the class
  Future<void> checkAuthAndInitialize() async {
    return _checkAuthAndInitialize();
  }
}
