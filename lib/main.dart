// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/providers/auth/auth_state_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/locale_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/theme_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/services/history/app_history_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:audio_service/audio_service.dart';
import 'package:medito/providers/player/ios_audio_handler.dart';
import 'package:medito/utils/audio_session_tracker.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/deep_link_service.dart';
// ignore: depend_on_referenced_packages
import 'package:device_preview/device_preview.dart';
import 'package:medito/config/debug_options.dart';
import 'scaffold_messenger_key.dart';
import 'app_globals.dart';
import 'package:medito/widgets/maintenance_checker_widget.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:medito/mock/mock_auth_api_service.dart';
import 'package:medito/mock/mock_donation_api_service.dart';
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';

// Completer used as both the guard and the barrier for duplicate main() calls.
// It is set synchronously before any await, so a second call always finds it non-null.
Completer<void>? _initCompleter;

Future<void> _configureStripe() async {
  // Configure Stripe settings - publishableKey and merchantIdentifier will be set from backend config
  Stripe.urlScheme = 'medito'; // Update this to match your app's URL scheme

  // Note: Stripe.instance.applySettings() and merchantIdentifier will be set after
  // publishableKey is set from the backend config in PaymentServiceProvider.getPaymentConfig()
}

void main() async {
  if (_initCompleter != null) {
    AppLogger.d('MAIN', 'App already initialized, skipping main()');
    await _initCompleter!.future;
    return;
  }
  _initCompleter = Completer<void>();

  AppLogger.d('MAIN', 'Starting app initialization');

  WidgetsFlutterBinding.ensureInitialized();

  if (isMockMode) {
    AppLogger.d('MAIN', 'Mock mode: skipping Firebase, Stripe, Meta SDK');
  }

  var prefs = await initializeSharedPreferences();

  try {
    final packageInfo = await PackageInfo.fromPlatform();
    await AppHistoryService.recordCurrentVersion(
      prefs,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  } catch (e) {
    AppLogger.w('MAIN', 'Failed to record version history: $e');
  }

  // ATT denial and consent flows previously wrote to 'analytics_enabled'
  // while the settings screen wrote to 'analytics_firebase_enabled'.
  // Consolidate: if the old key was set to false, honour that opt-out.
  const legacyKey = 'analytics_enabled';
  if (prefs.containsKey(legacyKey)) {
    final legacyValue = prefs.getBool(legacyKey)!;
    if (!legacyValue) {
      await prefs.setBool(
        SharedPreferenceConstants.analyticsFirebaseEnabled,
        false,
      );
    }
    await prefs.remove(legacyKey);
  }

  // One-time detection pass for users who had daily_reminder_enabled=true but
  // never actually granted POST_NOTIFICATIONS (the old flow requested
  // SCHEDULE_EXACT_ALARM instead, which isn't needed and blocked many users).
  // We flag them here; HomeView will prompt them immediately on first render.
  const notifPermissionMigrationKey = 'notif_permission_migration_v1';
  if (!(prefs.getBool(notifPermissionMigrationKey) ?? false)) {
    await prefs.setBool(notifPermissionMigrationKey, true);
    final remindersEnabled =
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ?? false;
    if (remindersEnabled) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await prefs.setBool(
          SharedPreferenceConstants.notifPermissionFixNeeded,
          true,
        );
      }
    }
  }

  if (!isMockMode) {
    // Initialize Firebase (non-blocking when offline).
    // On iOS, FirebaseApp.configure() may have already been called natively
    // from AppDelegate, so guard against the duplicate-app error.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final analyticsEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
          true;
      if (analyticsEnabled) {
        await CrashlyticsService().initialize();
      } else {
        // Explicitly disable Crashlytics collection so the SDK doesn't
        // phone home even though Firebase core is initialised.
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          false,
        );
      }
    } catch (e) {
      AppLogger.e('MAIN', 'Firebase initialization failed: $e');
      // Continue without Firebase - app should still work offline
    }

    // Initialize Stripe
    await _configureStripe();

    // Initialize Meta (Facebook) App Events
    // init() now checks the analyticsMetaEnabled preference internally
    // and skips SDK construction when disabled.
    await MetaSdkService.instance.init();
    AppLogger.d('MAIN', 'Meta SDK init complete');
  }

  await initializeAudioService();

  usePathUrlStrategy();

  _initCompleter?.complete();

  runApp(
    DevicePreview(
      enabled: DebugOptions.enableDevicePreview,
      builder: (context) => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (isMockMode) ...[
            donationServiceProvider.overrideWith(
              (ref) => MockDonationApiService(),
            ),
            paymentServiceProvider.overrideWith(
              (ref) => MockPaymentServiceImpl(),
            ),
            authRepositoryProvider.overrideWith((ref) async {
              return AuthRepositoryImpl(
                preferences: prefs,
                authService: MockAuthApiService(),
              );
            }),
          ],
        ],
        child: const ParentWidget(),
      ),
    ),
  );
}

void setupAudioCallback() {
  MeditoAudioServiceCallbackApi.setUp(AudioStateProvider(audioStateNotifier));
}

Future<void> initializeAudioService() async {
  if (Platform.isAndroid) {
    setupAudioCallback();
  } else if (Platform.isIOS) {
    iosAudioHandler = await AudioService.init(
      builder: () => IosAudioHandler(),
      config: const AudioServiceConfig(
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
      ),
    );
  }
}

class ParentWidget extends ConsumerStatefulWidget {
  static const String _title = 'Medito';

  const ParentWidget({super.key});

  @override
  ConsumerState<ParentWidget> createState() => _ParentWidgetState();
}

class _ParentWidgetState extends ConsumerState<ParentWidget>
    with WidgetsBindingObserver {
  DeepLinkService? _deepLinkService;

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    // If a previous run was force-quit mid-session and sent no event, recover
    // it as an audio_session_abandoned now (before any new session starts).
    unawaited(AudioSessionTracker.instance.replayIfAbandoned());
  }

  void _setUpSystemUi() {
    // Set default system UI style - will be updated in build method when theme is available
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _updateSystemUiForTheme(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && brightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _deepLinkService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Close auth state stream controller to prevent memory leaks
    disposeAuthStateController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);

    return authRepo.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Error initializing: $error'))),
      ),
      data: (_) {
        // Initialize deep link service once we have context
        if (_deepLinkService == null) {
          _deepLinkService = DeepLinkService(ref: ref, context: context);
          _deepLinkService!.initialize();
        }

        // Initialize auth state listener to handle navigation on force logout
        ref.watch(authStateListenerProvider);

        // Listen for auth state events that require navigation
        ref.listen<AsyncValue<AuthStateEvent>>(
          authStateStreamProvider,
          (_, state) => state.whenData((event) {
            switch (event) {
              case AuthStateEvent.forceLogout:
                _handleForceLogout(context);
                break;
            }
          }),
        );

        final locale = ref.watch(localeProvider);
        final themeMode = ref.watch(themeProvider);

        // Update system UI to match current theme
        _updateSystemUiForTheme(context);

        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.5,
          child: MaintenanceChecker(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: scaffoldMessengerKey,
              navigatorKey: navigatorKey,
              theme: appTheme(context, ThemeMode.light),
              darkTheme: appTheme(context, ThemeMode.dark),
              themeMode: themeMode,
              title: ParentWidget._title,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('es')],
              initialRoute: '/',
              routes: {
                '/': (context) => const SplashView(),
                SignUpLogInPage.routeName: (context) => const SignUpLogInPage(),
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppForegrounded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Analytics: leaving the app abandons a paused session. A session that is
      // actively playing keeps going in the background (screen-off mid-
      // meditation is normal), so the tracker only fires when not playing.
      unawaited(AudioSessionTracker.instance.onAppBackgrounded());
    }
  }

  void _onAppForegrounded() async {
    ref.read(firebaseMessagingProvider).ref.read(reminderProvider).clearBadge();
    ref.read(statsProvider.notifier).refresh();

    // Diagnose token state for debug purposes
    _diagnoseSecurity();

    _refreshAuthToken();

    if (Platform.isIOS) {
      // Process any pending track completions when app comes back to foreground
      processPendingCompletedTracks().then((processedCount) {
        if (processedCount > 0) {
          AppLogger.d(
            'STATS',
            'Processed $processedCount pending tracks on foreground',
          );
        }
      });
    }
  }

  Future<void> _diagnoseSecurity() async {
    try {
      // Get the HTTP service instance
      final httpService = HttpApiService();

      // Run diagnostic
      AppLogger.d('SECURITY', 'Running security diagnostic on app foreground');
      await httpService.diagnoseSecurity();
    } catch (e) {
      AppLogger.e('SECURITY', 'Error running security diagnostic', e);
    }
  }

  Future<void> _refreshAuthToken() async {
    try {
      final authRepository = ref.read(authRepositorySyncProvider);
      // The repository's getToken method will only refresh if token is expired
      if (authRepository.currentUser != null) {
        if (await authRepository.isLoggedIn()) {
          AppLogger.d('AUTH', 'Checking auth token after app foregrounded');
          await authRepository.getToken();
        }
      }
    } catch (e) {
      AppLogger.e('AUTH', 'Error with auth token on foreground', e);
      // Don't reset auth state here - let normal API calls handle auth errors
    }
  }

  // Handle force logout in UI layer
  void _handleForceLogout(BuildContext context) {
    // Add a small delay to ensure we're not in the middle of another operation
    Future.delayed(const Duration(milliseconds: 500), () {
      // Always reset the completer so deep links arriving during re-authentication
      // will wait for the app to be ready again rather than bypassing the check.
      appReadyCompleter = Completer<void>();
      // Check if we're already showing the SplashView by examining current route
      final currentRoute = ModalRoute.of(context);
      final isAlreadyOnSplash =
          currentRoute != null &&
          currentRoute.settings.name == SplashView.routeName;

      if (isAlreadyOnSplash) {
        AppLogger.d(
          'NAVIGATION',
          'Already on splash screen, refreshing instead of navigating',
        );
        // If already on splash, just reset state without navigating
        if (context.mounted) {
          final splash = context.findAncestorStateOfType<SplashViewState>();
          if (splash != null) {
            splash.checkAuthAndInitialize();
          }
        }
        return;
      }

      // If not on splash, navigate to it
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SplashView(),
          settings: RouteSettings(name: SplashView.routeName),
        ),
        (route) => false,
      );
    });
  }
}
