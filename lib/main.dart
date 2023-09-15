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
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Medito/providers/providers.dart';
import 'services/notifications/notifications_service.dart';

late SharedPreferences sharedPreferences;
late AudioPlayerNotifier audioHandler;
const audioBgEvent = 'com.medito.audio.bg.event';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  sharedPreferences = await SharedPreferences.getInstance();
  await Firebase.initializeApp();
  await registerNotification();
  await SentryFlutter.init(
    (options) {
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
  _runApp();
}

void _runApp() => runApp(
      ProviderScope(
        child: ParentWidget(),
      ),
    );

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
      unawaited(updateStatsFromBg());
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
    var streamEvent = audioHandler.trackAudioPlayer.playerStateStream
        .map((event) => event.processingState)
        .distinct();
    streamEvent.forEach((element) {
      if (element == ProcessingState.completed) {
        _handleAudioCompletion(ref);
      }
    });
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
        SystemUiOverlay.top, // Shows Status bar and hides Navigation bar
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

  void _handleAudioCompletion(
    WidgetRef ref,
  ) async {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    var extras = audioHandler.mediaItem.value?.extras;
    if (extras != null) {
      _handleAudioCompletionEvent(
        ref,
        extras['fileId'],
        extras['trackId'],
      );
      audioProvider.seekValueFromSlider(0);
      unawaited(audioProvider.pause());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioProvider.pause();
      });
      var router = ref.read(goRouterProvider);
      if (!(await _checkUser(ref))) {
        await router.push(
          RouteConstants.joinIntroPath,
          extra: {'screen': Screen.track},
        );
      }
    }
  }

  void _handleAudioCompletionEvent(
    WidgetRef ref,
    String audioFileId,
    String trackId,
  ) {
    var audio = AudioCompletedModel(
      audioFileId: audioFileId,
      trackId: trackId,
    );
    var event = EventsModel(
      name: EventTypes.audioCompleted,
      payload: audio.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  Future<bool> _checkUser(
    WidgetRef ref,
  ) async {
    var _user = ref.read(authProvider.notifier).userRes.body as UserTokenModel;

    return _user.email != null;
  }
}
