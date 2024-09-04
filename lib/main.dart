/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/
import 'dart:async';
import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/constants/theme/app_theme.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/src/audio_pigeon.g.dart';
import 'package:Medito/views/splash_view.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'constants/environments/environment_constants.dart';
import 'firebase_options.dart';
import 'services/notifications/firebase_notifications_service.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
var audioStateNotifier = AudioStateNotifier();
var currentEnvironment = kReleaseMode
    ? EnvironmentConstants.prodEnv
    : EnvironmentConstants.stagingEnv;

Future<void> main() async {
  await initializeApp();
  runAppWithSentry();
}

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnvironment();
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
      config: AudioServiceConfig(),
    );
  }
}

Future<void> runAppWithSentry() async {
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
        child: ParentWidget(),
      ),
    ),
  );
}

// ignore: prefer-match-file-name
class ParentWidget extends ConsumerStatefulWidget {
  static const String _title = 'Medito';

  @override
  ConsumerState<ParentWidget> createState() => _ParentWidgetState();
}

class _ParentWidgetState extends ConsumerState<ParentWidget>
    with WidgetsBindingObserver {
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    _initializeFirebaseMessaging();
  }

  void _initializeFirebaseMessaging() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firebaseMessaging = ref.read(firebaseMessagingProvider);
      firebaseMessaging.initialize(context, ref);
    });
  }

  Future<void> initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    await loadEnvironment();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    setupAudioCallback();
    await initializeAudioService();
    usePathUrlStrategy();
  }

  void _setUpSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ColorConstants.transparent,
        statusBarColor: ColorConstants.transparent,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [
        SystemUiOverlay.top,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: kDebugMode,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: appTheme(context),
      title: ParentWidget._title,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: SplashView(),
    );
  }
}
