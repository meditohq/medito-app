import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/providers/auth/auth_state_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/services/tiktok_events_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:device_preview/device_preview.dart';
import 'package:medito/config/debug_options.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
var audioStateNotifier = AudioStateNotifier();
bool _hasInitialized = false;
var appLinks = AppLinks();

void main() async {
  if (_hasInitialized) {
    return;
  }
  _hasInitialized = true;

  WidgetsFlutterBinding.ensureInitialized();

  await initializeAudioService();
  usePathUrlStrategy();

  var prefs = await initializeSharedPreferences();

  runApp(
    DevicePreview(
      enabled: DebugOptions.enableDevicePreview,
      builder: (context) => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
    _initTikTok();
  }

  Future<void> _initTikTok() async {
    await ref.read(tiktokEventsServiceProvider).initialise();
  }

  void _setUpSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light),
    );
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    debugPrint('[DEEPLINK] Setting up deep link handlers');

    // Handle links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DEEPLINK] Got deep link: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('[DEEPLINK] Error from link stream: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('[DEEPLINK] Handling deep link: ${uri.toString()}');
    debugPrint('[DEEPLINK] Scheme: ${uri.scheme}');
    debugPrint('[DEEPLINK] Host: ${uri.host}');
    debugPrint('[DEEPLINK] Path: ${uri.path}');

    var path = '';
    var id = '';

    try {
      if (uri.scheme == 'org.meditofoundation') {
        path = uri.host;
        id = uri.path.replaceFirst('/', '');
      } else if (uri.scheme == 'https' && uri.host == 'medito.app') {
        var pathSegments = uri.path.split('/')
          ..removeWhere((segment) => segment.isEmpty);

        if (pathSegments.isNotEmpty) {
          path = pathSegments[0];
          id = pathSegments.length > 1 ? pathSegments[1] : '';
        }
      } else {
        showSnackBar(
          context,
          StringConstants.invalidDeepLink,
        );
        return;
      }

      if (path.isEmpty) {
        showSnackBar(
          context,
          StringConstants.invalidDeepLink,
        );
        return;
      }

      debugPrint('[DEEPLINK] Navigating to: $path with id: $id');

      showSnackBar(
        context,
        StringConstants.followingDeepLink,
      );

      Future.delayed(const Duration(seconds: 2), () {
        handleNavigation(path, [id], context);
      });
    } catch (e) {
      debugPrint('[DEEPLINK] Error handling deep link: $e');
      showSnackBar(
        context,
        StringConstants.deepLinkError,
      );
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
    var connectionState = ref.watch(connectionNotifierProvider);

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

    connectionState.whenData((state) {
      if (state.status == InternetConnectionStatus.disconnected &&
          state.shouldShowMessage &&
          mounted) {
        showSnackBar(
          context,
          StringConstants.noConnection,
          actionLabel: StringConstants.goToDownloads,
          onActionPressed: () {
            handleNavigation(
                TypeConstants.flow, [TypeConstants.downloads], context);
          },
        );
      }
    });

    final featureFlags = ref.watch(featureFlagsProvider);
    if (featureFlags.isStreakFreezeEnabled) {
      _checkForFreezeUsage(ref);
    }

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.8,
      maxScaleFactor: 1.5,
      child: MaterialApp(
        debugShowCheckedModeBanner: kDebugMode,
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorKey: navigatorKey,
        theme: appTheme(context),
        title: ParentWidget._title,
        home: const SplashView(),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppForegrounded();
    }
  }

  void _onAppForegrounded() {
    ref.read(firebaseMessagingProvider).ref.read(reminderProvider).clearBadge();
    ref.read(statsProvider.notifier).refresh();

    // Diagnose token state for debug purposes
    _diagnoseSecurity();

    // Proactively refresh auth token when app comes to foreground
    _refreshAuthToken();

    if (Platform.isIOS) {
      // Process any pending track completions when app comes back to foreground
      processPendingCompletedTracks().then((processedCount) {
        if (processedCount > 0) {
          debugPrint('Processed $processedCount pending tracks on foreground');
        }
      });
    }
  }

  Future<void> _diagnoseSecurity() async {
    try {
      // Get the HTTP service instance
      final httpService = HttpApiService();

      // Run diagnostic
      debugPrint('Running security diagnostic on app foreground');
      await httpService.diagnoseSecurity();
    } catch (e) {
      debugPrint('Error running security diagnostic: $e');
    }
  }

  Future<void> _refreshAuthToken() async {
    try {
      final authRepository = ref.read(authRepositorySyncProvider);
      // The repository's getToken method will only refresh if token is expired
      if (authRepository.currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn =
            prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

        if (isLoggedIn) {
          debugPrint('Checking auth token after app foregrounded');
          await authRepository.getToken();
        }
      }
    } catch (e) {
      debugPrint('Error with auth token on foreground: $e');
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
        debugPrint(
            'Already on splash screen, refreshing instead of navigating');
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
