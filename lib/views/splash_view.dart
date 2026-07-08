// ignore_for_file: use_build_context_synchronously

import 'dart:async';

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
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/services/deep_link_service.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/app_globals.dart' show appReadyCompleter;
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  // Static route name for navigation
  static const routeName = 'SplashView';

  @override
  SplashViewState createState() => SplashViewState();
}

class SplashViewState extends ConsumerState<SplashView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  var _showAccountButtons = false;
  var _isLoading = true;
  var _currentTextIndex = 0;
  var _isSigningIn = false;
  late AnimationController _textAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupTextAnimation();
    _initialiseApp();
  }

  void _setupTextAnimation() {
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _textAnimationController.forward();
    _startTextCycle();
  }

  void _startTextCycle() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _textAnimationController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentTextIndex = (_currentTextIndex + 1) % 3;
        });
        _textAnimationController.forward();
        _startTextCycle();
      });
    });
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
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
          'SPLASH',
          'Current user before resume check: ${auth.currentUser}',
        );

        if (await auth.isLoggedIn()) {
          AppLogger.d('SPLASH', 'Checking auth status on resume');
          // getToken will only refresh if the current token is expired
          try {
            await auth.getToken();
            AppLogger.i(
              'SPLASH',
              'Token refresh successful on resume, current user: ${auth.currentUser}',
            );
            AppLogger.i(
              'SPLASH',
              'User email after resume: ${auth.getUserEmail()}',
            );
          } catch (e, stackTrace) {
            AppLogger.e(
              'SPLASH',
              'Token refresh failed on resume',
              e,
              stackTrace,
            );
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
      // First initialize Firebase (non-blocking when offline)
      try {
        await _initializeFirebase();
      } catch (e) {
        AppLogger.w(
          'SPLASH',
          'Firebase initialization failed, continuing offline: $e',
        );
        // Continue without Firebase - app should still work offline
      }

      // Then initialize Firebase Analytics separately (non-blocking when offline)
      try {
        await _initializeAnalytics();
      } catch (e) {
        AppLogger.w(
          'SPLASH',
          'Analytics initialization failed, continuing offline: $e',
        );
        // Continue without analytics - app should still work offline
      }

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
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.w('SPLASH', 'Firebase initialization timed out');
          throw Exception('Firebase initialization timeout');
        },
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
          .initialize(requestAttPermissionImmediately: false)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              AppLogger.w(
                'SPLASH',
                'Firebase Analytics initialization timed out',
              );
              throw Exception('Firebase Analytics initialization timeout');
            },
          );
      AppLogger.i(
        'SPLASH',
        'Firebase Analytics initialized with consent mode v2',
      );

      // Initialize Meta SDK and log first open once
      await MetaSdkService.instance.init().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          AppLogger.w('SPLASH', 'Meta SDK initialization timed out');
          throw Exception('Meta SDK initialization timeout');
        },
      );
      await MetaSdkService.instance.logAppFirstOpenOnce().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          AppLogger.w('SPLASH', 'Meta logAppFirstOpenOnce timed out');
          // Don't throw here as this is not critical
        },
      );
    } catch (e, stackTrace) {
      // Log the error but don't prevent app startup
      AppLogger.e(
        'SPLASH',
        'Error initializing Firebase Analytics',
        e,
        stackTrace,
      );
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
        'SPLASH',
        'Auth initialized, current user: ${auth.currentUser}',
      );
      AppLogger.i('SPLASH', 'User email from auth: ${auth.getUserEmail()}');

      // Set user ID for analytics immediately after user initialization
      // This ensures user ID is set before any events are logged
      try {
        final userId = ref.read(userIdProvider);
        if (userId != null && userId.isNotEmpty) {
          await FirebaseAnalyticsService().setUserId(userId);
          await MetaSdkService.instance.setUserId(userId);
          AppLogger.i('SPLASH', 'User ID set for analytics: $userId');
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'SPLASH',
          'Error setting user ID for analytics',
          e,
          stackTrace,
        );
      }

      // Wait for the initial deep link check to complete before applying UTM
      // parameters. On a fresh install from Apple Search Ads the deferred deep
      // link arrives via getInitialLink(); if we apply UTM params before that
      // completes the params won't be in SharedPreferences yet.
      try {
        await DeepLinkService.initialLinkProcessed.timeout(
          const Duration(seconds: 3),
        );
      } on TimeoutException {
        AppLogger.w(
          'SPLASH',
          'Initial link processing timed out, proceeding with UTM apply',
        );
      }

      // Apply stored UTM parameters from deep links (e.g., Apple Ads)
      // This should be done after user initialization to ensure proper attribution
      try {
        await FirebaseAnalyticsService.applyStoredUtmParameters();
      } catch (e, stackTrace) {
        AppLogger.e(
          'SPLASH',
          'Error applying stored UTM parameters',
          e,
          stackTrace,
        );
      }

      final currentUser = auth.currentUser;
      final isLoggedIn = await auth.isLoggedIn();
      AppLogger.i(
        'SPLASH',
        'Auth state: ${isLoggedIn ? 'logged in' : 'not logged in'}, has email: ${currentUser?.email != null}',
      );

      if (isLoggedIn && currentUser != null) {
        AppLogger.i('SPLASH', 'Initializing services for verified user...');
        // Try to initialize services, but don't fail if network is unavailable
        try {
          // Watchdog: services init is best-effort, so never let it pin the
          // user to the splash screen. Individual SDK calls can stall far
          // beyond their own timeouts on degraded networks (each HTTP
          // attempt burns up to 30s and the auth-refresh retries stack), and
          // a hung native call would otherwise block launch forever. On
          // timeout we take the same offline fallback as any other failure.
          await _initializeServices().timeout(const Duration(seconds: 20));
          AppLogger.i('SPLASH', 'Services initialized');

          if (!mounted) return;

          AppLogger.i('SPLASH', 'Navigation to main app...');
          if (!appReadyCompleter.isCompleted) appReadyCompleter.complete();
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  const RootPageView(firstChild: BottomNavigationBarView()),
            ),
          );
        } catch (e) {
          // If services initialization fails (likely due to network issues),
          // navigate to downloads view for offline access
          AppLogger.w(
            'SPLASH',
            'Services initialization failed, going offline: $e',
          );
          if (!mounted) return;

          showSnackBar(context, AppLocalizations.of(context)!.offlineMode);

          if (!appReadyCompleter.isCompleted) appReadyCompleter.complete();
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DownloadsView(isRoot: true),
            ),
          );
        }
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
        stackTrace,
      );
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
      if (!appReadyCompleter.isCompleted) appReadyCompleter.complete();
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    setState(() => _isSigningIn = true);
    var auth = ref.read(authRepositorySyncProvider);

    try {
      await auth.signInAnonymously();

      // Set user ID for analytics immediately after anonymous sign in
      try {
        final userId = ref.read(userIdProvider);
        if (userId != null && userId.isNotEmpty) {
          await FirebaseAnalyticsService().setUserId(userId);
          await MetaSdkService.instance.setUserId(userId);
          AppLogger.i(
            'SPLASH',
            'User ID set for analytics after anonymous sign in: $userId',
          );
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'SPLASH',
          'Error setting user ID for analytics after anonymous sign in',
          e,
          stackTrace,
        );
      }

      await _initializeServices().timeout(const Duration(seconds: 20));
      ref.read(meRefreshProvider)();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingPagerScreen()),
      );
    } on EmailExistsError catch (_) {
      if (!mounted) return;

      final shouldUseExistingAccount = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MeditoDialog(
          title: AppLocalizations.of(context)!.emailExistsDialogTitle,
          content: MeditoDialogBody(
            AppLocalizations.of(context)!.emailExistsDialogMessage,
          ),
          actions: [
            MeditoDialogSecondaryButton(
              label: AppLocalizations.of(
                context,
              )!.emailExistsContinueNewAccount,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            MeditoDialogPrimaryButton(
              label: AppLocalizations.of(context)!.emailExistsSignInWithEmail,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (shouldUseExistingAccount == true) {
        await Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (context) => const SignUpLogInPage()),
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
      AppLogger.e(
        'SPLASH',
        'Failed to initialize user (anonymous sign-in)',
        e,
        stackTrace,
      );
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

      // Kick off payment config fetch in the background so it is ready before
      // the donation screen opens. Errors are handled inside the provider.
      ref.read(paymentConfigProvider.future).ignore();

      // Initialize user data (don't fail if network is unavailable)
      try {
        AppLogger.i('SPLASH', 'Fetching user data...');
        final userData = await ref.read(meProvider.future);
        AppLogger.d('SPLASH', 'User data fetched: ${userData.toString()}');
      } catch (e, stackTrace) {
        // Check if this is a network error - if so, don't prevent app initialization
        if (e is NetworkConnectionError || e is TimeoutError) {
          AppLogger.w(
            'SPLASH',
            'Network error fetching user data, continuing offline: $e',
          );
        } else {
          AppLogger.e('SPLASH', 'Error fetching user data', e, stackTrace);
          CrashlyticsService().recordError(
            e,
            stackTrace,
            reason:
                'SplashView: Error fetching user data in _initializeServices',
          );
          // For non-network errors, re-throw to prevent app initialization
          rethrow;
        }
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
      // Re-throw to allow caller to handle offline scenario
      rethrow;
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
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
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
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight -
                                  MediaQuery.of(context).padding.top,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      top: 16,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(
                                              ((0.1).clamp(0.0, 1.0) * 255)
                                                  .round(),
                                            ),
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
                                    padding: const EdgeInsets.fromLTRB(
                                      32,
                                      24,
                                      32,
                                      0,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.splashHeadline,
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
                                        const SizedBox(height: 16),
                                        FadeTransition(
                                          opacity: _fadeAnimation,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            heightFactor: 1.0,
                                            child: Text(
                                              _getBenefitTitle(
                                                _currentTextIndex,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge
                                                  ?.copyWith(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.0,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_showAccountButtons) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        32,
                                        0,
                                        32,
                                        250,
                                      ),
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
                                                AppLocalizations.of(
                                                  context,
                                                )!.createAccountLogInButtonText,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                foregroundColor: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                                side: BorderSide(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                ),
                                              ),
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
                                                        context,
                                                      )!.continueAsGuest,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ), // IntrinsicHeight
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

  // Public method that can be called from outside the class
  Future<void> checkAuthAndInitialize() async {
    return _checkAuthAndInitialize();
  }
}
