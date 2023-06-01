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
import 'package:Medito/components/error_component.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/constants/theme/app_theme.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/stats_utils.dart';
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
  bool isFirstTimeLoading = true;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // update session stats when app comes into foreground
      updateStatsFromBg();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: ColorConstants.transparent,
      ),
    );

    // listened for app background/foreground events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    final auth = ref.watch(authProvider);
    if (!isFirstTimeLoading && auth.userEmail != null || auth.isAGuest) {
      ref.watch(currentMeditationPlayerProvider);
    }
    isFirstTimeLoading = false;
    if (connectivityStatus == ConnectivityStatus.isDisonnected) {
      return MaterialApp(
        home: ErrorComponent(onTap: () => {}, message: 'message'),
      );
    }

    return MaterialApp.router(
      routerConfig: router,
      theme: appTheme(context),
      title: ParentWidget._title,
    );
  }
}
