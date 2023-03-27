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
import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:async';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'audioplayer/audio_inherited_widget.dart';
import 'network/auth.dart';

late SharedPreferences sharedPreferences;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  sharedPreferences = await SharedPreferences.getInstance();

  var _audioHandler = await AudioService.init(
    builder: () => MeditoAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.medito.app.channel.audio',
      androidNotificationChannelName: 'Medito Session',
    ),
  );

  _audioHandler.customEvent.stream.listen((event) async {
    if (event == STATS) {
      await updateStatsFromBg();
    }
  });

  usePathUrlStrategy();

  if (kReleaseMode) {
    await SentryFlutter.init((options) {
      options.dsn = SENTRY_URL;
    }, appRunner: () => _runApp(_audioHandler));
  } else {
    _runApp(_audioHandler);
  }
}

void _runApp(MeditoAudioHandler _audioHandler) => runApp(ProviderScope(
      child: AudioHandlerInheritedWidget(
        audioHandler: _audioHandler,
        child: ParentWidget(),
      ),
    ));

/// This Widget is the main application widget.
class ParentWidget extends StatefulWidget {
  static const String _title = 'Medito';

  @override
  _ParentWidgetState createState() => _ParentWidgetState();
}

class _ParentWidgetState extends State<ParentWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: ColorConstants.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: ColorConstants.transparent),
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
          textTheme: meditoTextTheme(context)),
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
}

class SlideTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    animation = CurvedAnimation(curve: Curves.easeInOutExpo, parent: animation);

    return SlideTransition(
      position: Tween(begin: Offset(1.0, 0.0), end: Offset(0.0, 0.0))
          .animate(animation),
      child: child,
    );
  }
}
