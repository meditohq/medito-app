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
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Medito/providers/providers.dart';

late SharedPreferences sharedPreferences;
late AudioPlayerNotifier audioHandler;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  sharedPreferences = await SharedPreferences.getInstance();

  audioHandler = await AudioService.init(
    builder: () => AudioPlayerNotifier(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.medito.app.channel.audio',
      androidNotificationChannelName: 'Medito Session',
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
  @override
  void initState() {
    super.initState();
    ref.read(playerProvider.notifier).getCurrentlyPlayingSession();
    ref.read(audioPlayerNotifierProvider).initAudioHandler();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ColorConstants.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: ColorConstants.transparent,
      ),
    );

    // listened for app background/foreground events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentlyPlayingSession = ref.watch(playerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentlyPlayingSession != null) {
        checkAudioLocally(
          currentlyPlayingSession,
          currentlyPlayingSession.audio.first.files.first,
        );
      }
    });

    return MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        splashColor: ColorConstants.moonlight,
        canvasColor: ColorConstants.greyIsTheNewBlack,
        pageTransitionsTheme: PageTransitionsTheme(builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: SlideTransitionBuilder(),
        }),
        colorScheme: ColorScheme.dark(secondary: ColorConstants.walterWhite),
        textTheme: meditoTextTheme(context),
      ),
      title: ParentWidget._title,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // update session stats when app comes into foreground
      updateStatsFromBg();
    }
  }

  void checkAudioLocally(SessionModel sessionModel, SessionFilesModel file) {
    loadSessionAndBackgroundSound(sessionModel, file);
  }

  void loadSessionAndBackgroundSound(
    SessionModel sessionModel,
    SessionFilesModel file,
  ) {
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    var isPlaying = _audioPlayerNotifier.sessionAudioPlayer.playerState.playing;
    var _currentPlayingFileId =
        _audioPlayerNotifier.currentlyPlayingSession?.id;

    if (!isPlaying || _currentPlayingFileId != file.id) {
      setBackgroundSound(_audioPlayerNotifier, sessionModel.hasBackgroundSound);
      setSessionAudio(_audioPlayerNotifier, sessionModel, file);
    }
  }

  void setSessionAudio(
    AudioPlayerNotifier _audioPlayerNotifier,
    SessionModel sessionModel,
    SessionFilesModel file,
  ) {
    var checkDownloadedFile = ref.read(audioDownloaderProvider).getSessionAudio(
          '${sessionModel.id}-${file.id}${getFileExtension(file.path)}',
        );
    checkDownloadedFile.then((value) {
      _audioPlayerNotifier.setSessionAudio(sessionModel, file, filePath: value);
      _audioPlayerNotifier.currentlyPlayingSession = file;
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PLAY;
    });
  }

  void setBackgroundSound(
    AudioPlayerNotifier _audioPlayerNotifier,
    bool hasBackgroundSound,
  ) {
    if (hasBackgroundSound) {
      final _provider = ref.read(backgroundSoundsNotifierProvider);
      _provider.getBackgroundSoundFromPref().then((_) {
        if (_provider.selectedBgSound != null &&
            _provider.selectedBgSound?.title != StringConstants.NONE) {
          _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
          _audioPlayerNotifier.playBackgroundSound().catchError((err) {
          print(err);
        });
        }
      });
      _provider.getVolumeFromPref().then((_) {
        _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
      });
    } else {
      _audioPlayerNotifier.pauseBackgroundSound();
    }
  }
}

class SlideTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    animation = CurvedAnimation(curve: Curves.easeInOutExpo, parent: animation);

    return SlideTransition(
      position: Tween(begin: Offset(1.0, 0.0), end: Offset(0.0, 0.0))
          .animate(animation),
      child: child,
    );
  }
}
