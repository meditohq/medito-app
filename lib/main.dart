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
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/widgets/widgets.dart';

import 'constants/theme/app_theme.dart';

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
  await initializeApp();
  await _runApp();
}

Future<void> initializeApp() async {
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
  } else if (Platform.isAndroid) {
    setupAudioCallback();
    final manager = MeditoAndroidAudioServiceManager();
    await manager.startService();
  }
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
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setUpSystemUi();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var connectionStatus = ref.watch(internetConnectionProvider);

    connectionStatus.whenData((status) {
      if (status == InternetConnectionStatus.disconnected) {
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

    _checkForFreezeUsage(ref);

    return MaterialApp(
      debugShowCheckedModeBanner: kDebugMode,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      theme: appTheme(context),
      title: ParentWidget._title,
      home: SplashView(),
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
}
