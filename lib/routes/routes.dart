import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/root_page_view.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/background_sound/background_sound_view.dart';
import 'package:Medito/views/downloads/downloads_view.dart';
import 'package:Medito/views/folder/folder_view.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:Medito/views/session/session_view.dart';
import 'package:Medito/views/text/text_file_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/home/home_wrapper_widget.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: _rootNavigatorKey,
  initialLocation: RouteConstants.homePath,
  routes: [
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
            child: HomeWrapperWidget(),
          ),
        ),
        _getSessionRoute(fromRoot: true),
        _getArticleRoute(fromRoot: true),
        _getDailyRoute(fromRoot: true),
        _getWebviewRoute(fromRoot: true),
        _getBackgroundSoundRoute(),
        GoRoute(
          path: RouteConstants.collectionPath,
          routes: [_getPlayerRoute()],
          pageBuilder: (context, state) => getCollectionMaterialPage(state),
        ),
        GoRoute(
          path: RouteConstants.folderPath,
          routes: [
            _getSessionRoute(),
            _getArticleRoute(),
            _getWebviewRoute(),
            GoRoute(
              path: 'folder2/:f2id',
              routes: [
                _getSessionRoute(),
                _getArticleRoute(),
                _getWebviewRoute(),
                GoRoute(
                  path: 'folder3/:f3id',
                  pageBuilder: (context, state) => getFolderMaterialPage(state),
                  routes: [
                    _getSessionRoute(),
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
  ],
);

GoRoute _getDailyRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot ? RouteConstants.dailyPath : RouteConstants.dailyPath.sanitisePath(),
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getSessionOptionsDailyPage(state),
  );
}

GoRoute _getArticleRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot ? RouteConstants.articlePath : RouteConstants.articlePath.sanitisePath(),
    pageBuilder: (context, state) => getArticleMaterialPAge(state),
  );
}

GoRoute _getSessionRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot ? RouteConstants.sessionPath : RouteConstants.sessionPath.sanitisePath(),
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getSessionOptionsMaterialPage(state),
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
    path: RouteConstants.backgroundSoundsPath,
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: BackgroundSoundView(),
      );
    },
  );
}

GoRoute _getWebviewRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot ? RouteConstants.webviewPath : RouteConstants.webviewPath.sanitisePath(),
    pageBuilder: (context, state) {
      final url = state.extra! as Map;

      return MaterialPage(
        key: state.pageKey,
        child: WebViewComponent(url: url['url']!),
      );
    },
  );
}

//ignore: prefer-match-file-name
enum Screen {
  folder,
  player,
  article,
  stats,
  session,
  daily,
  donation,
  url,
  collection
}

MaterialPage<void> getSessionOptionsMaterialPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: SessionView(id: state.params['sid'], screenKey: Screen.session),
  );
}

MaterialPage<void> getArticleMaterialPAge(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: TextFileWidget(id: state.params['aid']),
  );
}

MaterialPage<void> getSessionOptionsDailyPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: SessionView(id: state.params['did'], screenKey: Screen.daily),
  );
}

//Can be altered to open other pages in the app other than Downloads (eg Faves)
MaterialPage<void> getCollectionMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: DownloadsView());
}

MaterialPage<void> getPlayerMaterialPage(GoRouterState state) {
  var session = state.extra as Map;

  return MaterialPage(
    key: state.pageKey,
    child: PlayerView(
      sessionModel: session['sessionModel'],
      file: session['file'],
    ),
  );
}

MaterialPage<void> getFolderMaterialPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: FolderView(id: state.params['fid']),
  );
  // if (params.length == 1) {
  //   return MaterialPage(
  //     key: state.pageKey, child: FolderView(id: state.params['fid']),
  //     // child: NewFolderScreen(id: state.params['fid']),
  //   );
  // } else {
  //   if (params.length == 2) {
  //     return MaterialPage(
  //       key: state.pageKey, child: FolderView(id: state.params['fid']),
  //       // child: NewFolderScreen(id: state.params['f2id']),
  //     );
  //   } else {
  //     return MaterialPage(
  //       key: state.pageKey, child: FolderView(id: state.params['fid']),
  //       // child: NewFolderScreen(id: state.params['f3id']),
  //     );
  //   }
  // }
}

String getPathFromString(String? place, List<String?> ids) {
  ids.removeWhere((element) => element == null);

  if (place == 'session') {
    return RouteConstants.sessionPath.replaceAll(':sid', ids.first!);
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
    return RouteConstants.folder3Path.replaceAll(':fid', ids.first!)
        .replaceAll(':f2id', ids[1]!)
        .replaceAll(':f3id', ids[2]!);
  }
  if (place != null && place.contains('folder2')) {
    return RouteConstants.folder2Path.replaceAll(':fid', ids.first!)
        .replaceAll(':f2id', ids[1]!);
  }
  if (place == 'folder') {
    return RouteConstants.folderPath.replaceAll(':fid', ids.first!);
  }
  if (place == 'url') {
    launchUrl(ids.first);
  }
  if (place == 'app') {
    return RouteConstants.collectionPath;
  }

  return '';
}
