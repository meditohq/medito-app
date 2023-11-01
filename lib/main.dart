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
import 'package:Medito/constants/constants.dart';
import 'package:Medito/constants/theme/app_theme.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:Medito/providers/providers.dart';
import 'services/notifications/notifications_service.dart';

late AudioPlayerNotifier audioHandler;
Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: StringConstants.prodEnv);

  var sharedPreferences = await initializeSharedPreferences();

  await Firebase.initializeApp();
  await registerNotification();

  await SentryFlutter.init(
    (options) {
      options.environment = kDebugMode
          ? HTTPConstants.ENVIRONMENT_DEBUG
          : HTTPConstants.ENVIRONMENT;
      options.dsn = HTTPConstants.SENTRY_DSN;
      options.tracesSampleRate = 1.0;
    },
  );

  audioHandler = await AudioService.init(
    builder: () => AudioPlayerNotifier(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.medito.app.channel.audio',
      androidNotificationChannelName: 'Medito Meditation',
      androidNotificationOngoing: true,
    ),
  );

  usePathUrlStrategy();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: ParentWidget(),
    ),
  );
}

// This Widget is the main application widget.
// ignore: prefer-match-file-name
class ParentWidget extends ConsumerStatefulWidget {
  static const String _title = 'Medito';

  @override
  ConsumerState<ParentWidget> createState() => _ParentWidgetState();
}

class _ParentWidgetState extends ConsumerState<ParentWidget>
    with WidgetsBindingObserver {
  AppLifecycleState currentState = AppLifecycleState.resumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(updateStatsFromBg(ref));
    } else if (state == AppLifecycleState.detached) {
      final audioProvider = ref.read(audioPlayerNotifierProvider);
      audioProvider.trackAudioPlayer.dispose();
      audioProvider.backgroundSoundAudioPlayer.dispose();
      audioProvider.dispose();
    }
    currentState = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    audioProvider.trackAudioPlayer.dispose();
    audioProvider.backgroundSoundAudioPlayer.dispose();
    audioProvider.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    onMessageAppOpened(ref);
    initializeNotification(ref);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      theme: appTheme(context),
      title: ParentWidget._title,
    );
  }
}
