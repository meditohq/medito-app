import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/splash_view.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'constants/environments/environment_constants.dart';
import 'constants/theme/app_theme.dart';
import 'firebase_options.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
var audioStateNotifier = AudioStateNotifier();
var currentEnvironment = kReleaseMode
    ? EnvironmentConstants.prodEnv
    : EnvironmentConstants.stagingEnv;

//Temp main for ios
void main() async {
  await initializeApp();
  _runAppWithSentry();
}

Future<void> initializeApp() async {
  await loadEnvironment();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setupAudioCallback();
  await initializeAudioService();
  usePathUrlStrategy();
}

Future<void> loadEnvironment() async {
  await dotenv.load(fileName: currentEnvironment);
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
      options.environment = kDebugMode
          ? HTTPConstants.ENVIRONMENT_DEBUG
          : HTTPConstants.ENVIRONMENT;
      options.dsn = HTTPConstants.SENTRY_DSN;
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
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialConnectivity();
    _initializeConnectivityListener();
  }

  void _setUpSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ColorConstants.transparent,
      statusBarColor: ColorConstants.transparent,
    ));
  }

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          _updateConnectionStatus,
        );
  }

  Future<void> _checkInitialConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      _showNoConnectionSnackBar();
    } else {
      _hideNoConnectionSnackBar();
    }
  }

  void _hideNoConnectionSnackBar() {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }

  void _showNoConnectionSnackBar() {
    if (scaffoldMessengerKey.currentState?.mounted ?? false) {
      scaffoldMessengerKey.currentState!
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(StringConstants.noConnectionMessage),
            duration: const Duration(days: 365),
            action: SnackBarAction(
              label: StringConstants.goToDownloads,
              onPressed: () {
                scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
                _navigateToDownloads(context);
              },
            ),
          ),
        );
    }
  }

  void _navigateToDownloads(BuildContext context) {
    handleNavigation(TypeConstants.flow, ['downloads'], context, ref: ref);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: kDebugMode,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      // Add this line
      theme: appTheme(context),
      title: ParentWidget._title,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: const SplashView(),
    );
  }
}
