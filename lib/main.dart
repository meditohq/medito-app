// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/constants/widget_constants.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/providers/auth/auth_state_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:medito/utils/widget_updater.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/services/network/http_api_service.dart';
// ignore: depend_on_referenced_packages
import 'package:device_preview/device_preview.dart';
import 'package:medito/config/debug_options.dart';
import 'package:medito/widgets/maintenance_checker_widget.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
var audioStateNotifier = AudioStateNotifier();
bool _hasInitialized = false;
var appLinks = AppLinks();
Timer? _widgetUpdateTimer;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == WidgetConstants.taskName) {
      try {
        // You may need to re-initialize dependencies here
        var statsManager = StatsManager();
        await statsManager.initialize();
        try {
          await statsManager.sync();
        } catch (e) {}
        var stats = await statsManager.localAllStats;
        await updateWidgets(stats);
      } catch (e) {}
    }

    return Future.value(true);
  });
}

void main() async {
  if (_hasInitialized) {
    return;
  }
  _hasInitialized = true;

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Crashlytics
  if (kDebugMode) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  } else {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (errorDetails) {
    if (errorDetails.exception is PathNotFoundException &&
        errorDetails.exception.toString().contains('libCachedImageData')) {
      debugPrint(
          'Caught PathNotFoundException for cached image: ${errorDetails.exception}');
      return;
    }
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    originalOnError?.call(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await initializeAudioService();
  usePathUrlStrategy();

  var prefs = await initializeSharedPreferences();

  _setUpWidget();

  if (Platform.isAndroid) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    Workmanager().registerPeriodicTask(
      WidgetConstants.taskIdentifier,
      WidgetConstants.taskName,
      frequency: const Duration(minutes: 2),
      initialDelay: const Duration(minutes: 0),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  runApp(
    DevicePreview(
      enabled: DebugOptions.enableDevicePreview,
      builder: (context) => ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ParentWidget(),
      ),
    ),
  );
}

void setupAudioCallback() {
  MeditoAudioServiceCallbackApi.setUp(AudioStateProvider(audioStateNotifier));
}

Future<void> initializeAudioService() async {
  if (Platform.isIOS) {
    await AudioService.init(
      builder: () => iosAudioHandler,
      config: AudioServiceConfig(
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );
  } else if (Platform.isAndroid) {
    setupAudioCallback();
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
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  void _setUpSystemUi() {
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

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    AppLogger.d('DEEPLINK', 'Setting up deep link handlers');

    // Handle links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        AppLogger.d('DEEPLINK', 'Got deep link: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        AppLogger.e('DEEPLINK', 'Error from link stream', err);
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    AppLogger.d('DEEPLINK', 'Handling deep link: ${uri.toString()}');
    AppLogger.d('DEEPLINK', 'Scheme: ${uri.scheme}');
    AppLogger.d('DEEPLINK', 'Host: ${uri.host}');
    AppLogger.d('DEEPLINK', 'Path: ${uri.path}');

    try {
      var pathSegments = <String>[];

      if (uri.scheme == 'org.meditofoundation') {
        pathSegments = [uri.host, ...uri.pathSegments];
      } else if (uri.scheme == 'https' && uri.host == 'medito.app') {
        pathSegments = uri.pathSegments;
      } else {
        showSnackBar(context, StringConstants.invalidDeepLink);
        return;
      }

      if (pathSegments.isEmpty) {
        showSnackBar(context, StringConstants.invalidDeepLink);
        return;
      }

      // Handle OTP links
      if (pathSegments[0] == 'otp' ||
          pathSegments[1] == 'otp' && pathSegments.length > 1) {
        return;
      }

      // Handle other navigation links
      var path = pathSegments[0];
      var id = pathSegments.length > 1 ? pathSegments[1] : '';

      AppLogger.d('DEEPLINK', 'Navigating to: $path with id: $id');

      showSnackBar(context, StringConstants.followingDeepLink);

      Future.delayed(const Duration(seconds: 2), () {
        handleNavigation(path, [id], context);
      });
    } catch (e) {
      AppLogger.e('DEEPLINK', 'Error handling deep link', e);
      showSnackBar(context, StringConstants.deepLinkError);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
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
        home: Scaffold(
          body: Center(child: Text('Error initializing: $error')),
        ),
      ),
      data: (_) {
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

        final featureFlags = ref.watch(featureFlagsProvider);
        if (featureFlags.isStreakFreezeEnabled) {
          // _checkForFreezeUsage(ref);
        }

        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.5,
          child: MaintenanceChecker(
            child: MaterialApp(
              debugShowCheckedModeBanner: kDebugMode,
              scaffoldMessengerKey: scaffoldMessengerKey,
              navigatorKey: navigatorKey,
              theme: appTheme(context),
              title: ParentWidget._title,
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
    }
  }

  void _onAppForegrounded() async {
    ref.read(firebaseMessagingProvider).ref.read(reminderProvider).clearBadge();
    ref.read(statsProvider.notifier).refresh();

    // Diagnose token state for debug purposes
    _diagnoseSecurity();

    _refreshAuthToken();

    _updateWidgetsData();

    if (Platform.isIOS) {
      // Process any pending track completions when app comes back to foreground
      processPendingCompletedTracks().then((processedCount) {
        if (processedCount > 0) {
          AppLogger.d(
            'STATS',
            'Processed $processedCount pending tracks on foreground',
          );

          // Update widgets again if tracks were processed
          _updateWidgetsData();
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

  void _checkForFreezeUsage(WidgetRef ref) {
    final stats = ref.watch(statsProvider).valueOrNull;
    final isDonor =
        ref.watch(meProvider).valueOrNull?.hasActiveSubscription ?? false;

    if (stats != null && isDonor && stats.freezeUsageDates.isNotEmpty == true) {
      final lastFreezeUse = stats.freezeUsageDates.last;
      _hasShownFreezeAlert(lastFreezeUse).then((hasShown) {
        if (!hasShown) {
          _showFreezeUsedAlert(context);
          _markFreezeAlertShown(lastFreezeUse);
        }
      });
    }
  }

  Future<bool> _hasShownFreezeAlert(int timestamp) async {
    final prefs = ref.read(sharedPreferencesProvider);
    return (prefs.getInt('last_freeze_alert') ?? 0) >= timestamp;
  }

  Future<void> _markFreezeAlertShown(int timestamp) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('last_freeze_alert', timestamp);
  }

  void _showFreezeUsedAlert(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          StringConstants.freezeUsedMessage,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  // Handle force logout in UI layer
  void _handleForceLogout(BuildContext context) {
    // Add a small delay to ensure we're not in the middle of another operation
    Future.delayed(const Duration(milliseconds: 500), () {
      // Check if we're already showing the SplashView by examining current route
      final currentRoute = ModalRoute.of(context);
      final isAlreadyOnSplash = currentRoute != null &&
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

void _setUpWidget() {
  // Set the app group ID for HomeWidget usage
  HomeWidget.setAppGroupId(WidgetConstants.widgetGroupId);

  // Schedule periodic updates for widgets
  _widgetUpdateTimer?.cancel();
  _widgetUpdateTimer = Timer.periodic(
    kDebugMode ? const Duration(minutes: 5) : const Duration(minutes: 30),
    (timer) async {
      await _updateWidgetsData();
    },
  );

  // Register for widget launcher
  HomeWidget.widgetClicked.listen((uri) {
    AppLogger.d('WIDGET', 'Widget clicked: $uri');
    // Handle widget tap events if needed
  });

  // Initial update
  _updateWidgetsData();
}

Future<void> _updateWidgetsData() async {
  try {
    AppLogger.d('WIDGET', 'Updating widget data');

    // Initialize Firebase if needed
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    var statsManager = StatsManager();
    await statsManager.initialize();

    try {
      await statsManager.sync();
    } catch (e) {
      AppLogger.e('WIDGET', 'Stats sync failed', e);
    }

    var stats = await statsManager.localAllStats;
    await updateWidgets(stats);

    AppLogger.d('WIDGET', 'Widget data updated successfully');
  } catch (e) {
    AppLogger.e('WIDGET', 'Widget update failed', e);
  }
}
