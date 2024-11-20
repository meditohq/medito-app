import 'dart:async';
import 'dart:core';
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
import 'package:medito/constants/work_manager.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/network/dio_header_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/splash_view.dart';
import 'package:workmanager/workmanager.dart';

import 'constants/theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:medito/repositories/auth/auth_repository.dart';

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

  _setUpWidget();
  await initializeApp();
  await _runApp();
}

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AuthRepositoryImpl.initializeSupabase();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setupAudioCallback();
  await initializeAudioService();
  usePathUrlStrategy();
}

Future<void> initializeAudioService() async {
  if (Platform.isIOS) {
    await AudioService.init(
      builder: () => iosAudioHandler,
      config: const AudioServiceConfig(),
    );
  }
}

void setupAudioCallback() {
  MeditoAudioServiceCallbackApi.setup(AudioStateProvider(audioStateNotifier));
}

@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

      if (task == WidgetConstants.taskName) {
        await HomeWidget.setAppGroupId(WidgetConstants.widgetGroupId);

        var statsManager = StatsManager();
        await statsManager.initialize();

        try {
          await statsManager.sync();
        } catch (e) {
          if (kDebugMode) print('Stats sync failed: $e');
        }

        var stats = await statsManager.localAllStats;
        await updateWidgets(stats);

        return Future.value(true);
      }
      return Future.value(false);
    } catch (e) {
      if (kDebugMode) print('Widget update failed: $e');
      return Future.value(false);
    }
  });
}

void _setUpWidget() {
  // Initialize Workmanager with the dispatcher callback
  Workmanager().initialize(
    widgetCallbackDispatcher,
    isInDebugMode: kDebugMode,
  );

  // Register periodic background task for iOS and Android
  Workmanager().registerPeriodicTask(
    WidgetConstants.taskIdentifier,
    WidgetConstants.taskName,
    frequency:
        kDebugMode ? const Duration(minutes: 15) : const Duration(minutes: 45),
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 1),
  );

  // Set the app group ID for HomeWidget usage
  HomeWidget.setAppGroupId(WidgetConstants.widgetGroupId);
}

Future<void> _runApp() async {
  var prefs = await initializeSharedPreferences();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ParentWidget(),
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
  late DioHeaderService dioHeaderService;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

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

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    _initializeDioHeaderService();
    _initDeepLinks();
  }

  Future<void> _initializeDioHeaderService() async {
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    dioHeaderService = DioHeaderService(deviceInfo);
    await dioHeaderService.initialise();
  }

  Future<void> _onAppForegrounded() async {
    ref.read(reminderProvider).clearBadge();
    ref.invalidate(statsProvider);
  }

  void _setUpSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.dark),
    );
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    if (kDebugMode) {
      print('[DEEPLINK] Setting up deep link handlers');
    }

    // Handle links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (kDebugMode) {
          print('[DEEPLINK] Got deep link: $uri');
        }
        _handleDeepLink(uri);
      },
      onError: (err) {
        if (kDebugMode) {
          print('[DEEPLINK] Error from link stream: $err');
        }
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      print('[DEEPLINK] Handling deep link: ${uri.toString()}');
      print('[DEEPLINK] Scheme: ${uri.scheme}');
      print('[DEEPLINK] Host: ${uri.host}');
      print('[DEEPLINK] Path: ${uri.path}');
    }

    var path = '';
    var id = '';

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
      return;
    }

    if (kDebugMode) {
      print('[DEEPLINK] Navigating to: $path with id: $id');
    }

    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Following deep link...'),
        duration: Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      handleNavigation(path, [id], context);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
