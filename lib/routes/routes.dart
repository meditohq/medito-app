import 'package:Medito/models/models.dart';
import 'package:Medito/views/home/home_view.dart';
import 'package:Medito/views/notifications/notification_permission_view.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/root_page_view.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/auth/join_email_view.dart';
import 'package:Medito/views/auth/join_intro_view.dart';
import 'package:Medito/views/auth/join_verify_OTP_view.dart';
import 'package:Medito/views/auth/join_welcome_view.dart';
import 'package:Medito/views/background_sound/background_sound_view.dart';
import 'package:Medito/views/downloads/downloads_view.dart';
import 'package:Medito/views/folder/folder_view.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:Medito/views/track/track_view.dart';
import 'package:Medito/views/splash_view.dart';
import 'package:Medito/views/text/text_file_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return router;
});
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: _rootNavigatorKey,
  initialLocation: RouteConstants.root,
  routes: [
    GoRoute(
      path: RouteConstants.root,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: SplashView(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RouteConstants.joinIntroPath,
      pageBuilder: (context, state) {
        final params =
            state.extra != null ? state.extra as JoinRouteParamsModel : null;

        return MaterialPage(
          key: state.pageKey,
          child: JoinIntroView(fromScreen: params?.screen ?? Screen.splash),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RouteConstants.joinEmailPath,
      pageBuilder: (context, state) {
        final params =
            state.extra != null ? state.extra as JoinRouteParamsModel : null;

        return MaterialPage(
          key: state.pageKey,
          child: JoinEmailView(fromScreen: params?.screen ?? Screen.splash),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RouteConstants.joinVerifyOTPPath,
      pageBuilder: (context, state) {
        final params =
            state.extra != null ? state.extra as JoinRouteParamsModel : null;

        return MaterialPage(
          key: state.pageKey,
          child: JoinVerifyOTPView(
            email: params?.email ?? '',
            fromScreen: params?.screen ?? Screen.splash,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RouteConstants.joinWelcomePath,
      pageBuilder: (context, state) {
        final params =
            state.extra != null ? state.extra as JoinRouteParamsModel : null;

        return MaterialPage(
          key: state.pageKey,
          child: JoinWelcomeView(
            email: params?.email ?? '',
            fromScreen: params?.screen ?? Screen.splash,
          ),
        );
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => RootPageView(
        firstChild: child,
      ),
      routes: [
        GoRoute(
          path: RouteConstants.homePath,
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: HomeView(),
          ),
          routes: [
            _getWebviewRoute(),
          ],
        ),
        _getTrackRoute(fromRoot: true),
        _getArticleRoute(fromRoot: true),
        _getDailyRoute(fromRoot: true),
        _getWebviewRoute(fromRoot: true),
        _getConnectivityErrorRoute(fromRoot: true),
        _getDownloadsRoute(fromRoot: true),
        GoRoute(
          path: RouteConstants.collectionPath,
          routes: [
            _getPlayerRoute(),
          ],
          pageBuilder: (context, state) => getCollectionMaterialPage(state),
        ),
        GoRoute(
          path: RouteConstants.folderPath,
          routes: [
            _getTrackRoute(),
            _getArticleRoute(),
            _getWebviewRoute(),
            GoRoute(
              path: 'folder2/:f2id',
              routes: [
                _getTrackRoute(),
                _getArticleRoute(),
                _getWebviewRoute(),
                GoRoute(
                  path: 'folder3/:f3id',
                  pageBuilder: (context, state) => getFolderMaterialPage(state),
                  routes: [
                    _getTrackRoute(),
                    _getArticleRoute(),
                    _getWebviewRoute(),
                  ],
                ),
              ],
              pageBuilder: (context, state) => getFolderMaterialPage(state),
            ),
          ],
          pageBuilder: (context, state) => getFolderMaterialPage(state),
        ),
      ],
    ),
    _getBackgroundSoundRoute(),
    _getNotificationPermissionRoute(),
  ],
);

GoRoute _getDailyRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.dailyPath
        : RouteConstants.dailyPath.sanitisePath(),
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getTrackOptionsDailyPage(state),
  );
}

GoRoute _getArticleRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.articlePath
        : RouteConstants.articlePath.sanitisePath(),
    pageBuilder: (context, state) => getArticleMaterialPAge(state),
  );
}

GoRoute _getTrackRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.trackPath
        : RouteConstants.trackPath.sanitisePath(),
    routes: [
      _getPlayerRoute(),
      _getWebviewRoute(),
    ],
    pageBuilder: (context, state) => getTrackOptionsMaterialPage(state),
  );
}

GoRoute _getPlayerRoute() {
  return GoRoute(
    path: RouteConstants.playerPath.sanitisePath(),
    pageBuilder: (context, state) {
      return getPlayerMaterialPage(state);
    },
    routes: [_getWebviewRoute()],
  );
}

GoRoute _getBackgroundSoundRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: RouteConstants.backgroundSoundsPath,
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: BackgroundSoundView(),
      );
    },
  );
}

GoRoute _getNotificationPermissionRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: RouteConstants.notificationPermissionPath,
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: NotificationPermissionView(),
      );
    },
  );
}

GoRoute _getWebviewRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.webviewPath
        : RouteConstants.webviewPath.sanitisePath(),
    pageBuilder: (context, state) {
      final url = state.extra! as Map;

      return MaterialPage(
        key: state.pageKey,
        child: MeditoWebViewWidget(url: url['url']!),
      );
    },
  );
}

GoRoute _getConnectivityErrorRoute({bool fromRoot = false}) {
  return GoRoute(
    parentNavigatorKey: _shellNavigatorKey,
    path: fromRoot
        ? RouteConstants.connectivityErrorPath
        : RouteConstants.connectivityErrorPath.sanitisePath(),
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: ConnectivityErrorWidget(),
      );
    },
  );
}

GoRoute _getDownloadsRoute({bool fromRoot = false}) {
  return GoRoute(
    parentNavigatorKey: _shellNavigatorKey,
    path: fromRoot
        ? RouteConstants.downloadsPath
        : RouteConstants.downloadsPath.sanitisePath(),
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: DownloadsView(),
      );
    },
  );
}

//ignore: prefer-match-file-name
enum Screen {
  splash,
  folder,
  player,
  article,
  stats,
  track,
  daily,
  donation,
  url,
  collection
}

MaterialPage<void> getTrackOptionsMaterialPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: TrackView(id: state.params['sid'] ?? ''),
  );
}

MaterialPage<void> getArticleMaterialPAge(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: TextFileWidget(id: state.params['aid']),
  );
}

MaterialPage<void> getTrackOptionsDailyPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: TrackView(id: state.params['did'] ?? ''),
  );
}

//Can be altered to open other pages in the app other than Downloads (eg Faves)
MaterialPage<void> getCollectionMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: DownloadsView());
}

MaterialPage<void> getPlayerMaterialPage(GoRouterState state) {
  var track = state.extra as Map;

  return MaterialPage(
    key: state.pageKey,
    child: PlayerView(
      trackModel: track['trackModel'],
      file: track['file'],
    ),
  );
}

MaterialPage<void> getFolderMaterialPage(GoRouterState state) {
  var folderId =
      state.params['f3id'] ?? state.params['f2id'] ?? state.params['fid'];

  return MaterialPage(
    key: state.pageKey,
    child: FolderView(id: folderId ?? ''),
  );
}

String getPathFromString(String? place, List<String?> ids) {
  ids.removeWhere((element) => element == null);

  if (place == 'track') {
    return RouteConstants.trackPath.replaceAll(':sid', ids.first!);
  }
  if (place == 'daily') {
    return RouteConstants.dailyPath.replaceAll(':did', ids.first!);
  }
  if (place == 'donation') {
    return RouteConstants.donationPath;
  }
  if (place == 'article') {
    return RouteConstants.articlePath.replaceAll(':aid', ids.first!);
  }
  if (place != null && place.contains('folder3')) {
    return RouteConstants.folder3Path
        .replaceAll(':fid', ids.first!)
        .replaceAll(':f2id', ids[1]!)
        .replaceAll(':f3id', ids[2]!);
  }
  if (place != null && place.contains('folder2')) {
    return RouteConstants.folder2Path
        .replaceAll(':fid', ids.first!)
        .replaceAll(':f2id', ids[1]!);
  }
  if (place == 'folder') {
    return RouteConstants.folderPath.replaceAll(':fid', ids.first!);
  }
  if (place == 'url') {
    launchUrlMedito(ids.first);
  }
  if (place == TypeConstants.LINK) {
    return RouteConstants.webviewPath;
  }
  if (place == 'app') {
    return RouteConstants.collectionPath;
  }

  return '';
}
