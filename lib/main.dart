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
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/network/dio_header_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/splash_view.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'constants/theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
var audioStateNotifier = AudioStateNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var appLinks = AppLinks();

  // Handle app links while the app is already started - deep link
  appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      // Handle the deep link
      if (kDebugMode) {
        print('Deep link: $uri');
      }
    }
  });

  await initializeApp();
  _runAppWithSentry();
}

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setupAudioCallback();
  await initializeAudioService();
  usePathUrlStrategy();
}

void setupAudioCallback() {
  MeditoAudioServiceCallbackApi.setup(AudioStateProvider(audioStateNotifier));
}

Future<void> initializeAudioService() async {
  if (Platform.isIOS) {
    await AudioService.init(
      builder: () => iosAudioHandler,
      config: const AudioServiceConfig(),
    );
  }
}

Future<void> _runAppWithSentry() async {
  var prefs = await initializeSharedPreferences();
  SentryFlutter.init(
    (options) {
      options.attachScreenshot = true;
      options.environment = environment;
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const ParentWidget(),
      ),
    ),
  );
}

class ParentWidget extends ConsumerStatefulWidget {
  static const String _title = 'Medito';

  const ParentWidget({super.key});

  @override
  ConsumerState<ParentWidget> createState() => _ParentWidgetState();
}

class _ParentWidgetState extends ConsumerState<ParentWidget>
    with WidgetsBindingObserver {
  StreamSubscription? _sub;
  late final StreamSubscription<InternetStatus> _connectivityListener;
  late DioHeaderService dioHeaderService;

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinkListener();
    _handleInitialUri();
    _initializeDioHeaderService().then(
      (_) {
        _checkInitialConnectivity();
      },
    );
  }

  Future<void> _initializeDioHeaderService() async {
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    dioHeaderService = DioHeaderService(deviceInfo);
    await dioHeaderService.initialise();
  }

  void _initDeepLinkListener() {
    _sub = AppLinks().uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      if (kDebugMode) {
        print('Deep link error: $err');
      }
    });
  }

  Future<void> _handleInitialUri() async {
    try {
      final initialUri = await AppLinks().getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling initial URI: $e');
      }
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    await Future.delayed(const Duration(seconds: 2));

    var pathSegments = uri.pathSegments;
    if (pathSegments.length >= 2) {
      var trackId = pathSegments[1];
      handleNavigation(
          pathSegments[0], [trackId], navigatorKey.currentContext!);
    } else {
      if (kDebugMode) {
        print('Invalid deep link format');
      }
    }
  }

  void _setUpSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ColorConstants.transparent,
      statusBarColor: ColorConstants.transparent,
    ));
  }

  Future<void> _checkInitialConnectivity() async {
    _connectivityListener =
        InternetConnection().onStatusChange.listen((InternetStatus status) {
      switch (status) {
        case InternetStatus.connected:
          _hideNoConnectionSnackBar();
          StatsManager().sync().then((_) => ref.invalidate(statsProvider));
          break;
        case InternetStatus.disconnected:
          _showNoConnectionSnackBar();
          break;
      }
    });
  
    return;
  }

  void _hideNoConnectionSnackBar() {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }

  void _showNoConnectionSnackBar() {
    var currentState = scaffoldMessengerKey.currentState;
    if (currentState?.mounted ?? false) {
      currentState!
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(StringConstants.noConnectionMessage),
            duration: const Duration(days: 365),
            action: SnackBarAction(
              label: StringConstants.goToDownloads,
              onPressed: () {
                currentState.hideCurrentSnackBar();
                _navigateToDownloads(context);
              },
            ),
          ),
        );
    }
  
    return;
  }

  void _navigateToDownloads(BuildContext context) {
    handleNavigation(TypeConstants.flow, ['downloads'], context, ref: ref);
  }

  @override
  void dispose() {
    _connectivityListener.cancel();
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: kDebugMode,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      theme: appTheme(context),
      title: ParentWidget._title,
      home: const SplashView(),
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
    ref.invalidate(statsProvider);
  }
}
