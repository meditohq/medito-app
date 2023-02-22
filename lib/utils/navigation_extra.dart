import 'package:Medito/components/components.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/background_sound/background_sound_view.dart';
import 'package:Medito/views/btm_nav/downloads_widget.dart';
import 'package:Medito/views/folder/folder_view.dart';
import 'package:Medito/views/session/session_view.dart';
import 'package:Medito/views/text/text_file_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../views/home/home_wrapper_widget.dart';
import '../views/player/player2/player_view.dart';

const String SessionPath = '/session/:sid';
const String DailyPath = '/daily/:did';
const String DonationPath = '/donation';
const String PlayerPath = '/player';
const String ArticlePath = '/article/:aid';
const String FolderPath = '/folder/:fid';
const String Player1 = '/folder/:fid/session/:sid';
const String Folder2Path = '/folder/:fid/folder2/:f2id';
const String Player2 = '/folder/:fid/folder2/:f2id/session/:sid';
const String Folder3Path = '/folder/:fid/folder2/:f2id/folder3/:f3id';
const String Player3 = '/folder/:fid/folder2/:f2id/folder3/:f3id/session/:sid';
const String UrlPath = '/url';
const String CollectionPath = '/app';
const String webviewPath = '/webview';
const String backgroundSounds = '/backgroundsounds';
const String HomePath = '/';

final router = GoRouter(
  urlPathStrategy: UrlPathStrategy.path,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
        path: HomePath,
        builder: (context, state) => HomeWrapperWidget(),
        routes: [
          _getSessionRoute(),
          _getArticleRoute(),
          _getDailyRoute(),
          _getWebviewRoute(),
          GoRoute(
            path: 'app',
            routes: [_getPlayerRoute()],
            pageBuilder: (context, state) => getCollectionMaterialPage(state),
          ),
          GoRoute(
            path: 'folder/:fid',
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
                    pageBuilder: (context, state) =>
                        getFolderMaterialPage(state),
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
        ]),
  ],
);

GoRoute _getDailyRoute() {
  return GoRoute(
    path: 'daily/:did',
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getSessionOptionsDailyPage(state),
  );
}

GoRoute _getArticleRoute() {
  return GoRoute(
    path: 'article/:aid',
    pageBuilder: (context, state) => getArticleMaterialPAge(state),
  );
}

GoRoute _getSessionRoute() {
  return GoRoute(
    path: 'session/:sid',
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getSessionOptionsMaterialPage(state),
  );
}

GoRoute _getPlayerRoute() {
  return GoRoute(
      path: 'player',
      pageBuilder: (context, state) {
        return getPlayerMaterialPage(state);
      },
      routes: [_getWebviewRoute(), _getBackgroundSoundRoute()]);
}

GoRoute _getBackgroundSoundRoute() {
  return GoRoute(
    path: 'backgroundSounds',
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: BackgroundSoundView(),
      );
    },
  );
}

GoRoute _getWebviewRoute() {
  return GoRoute(
    path: 'webview',
    pageBuilder: (context, state) {
      final url = state.extra! as Map;
      return MaterialPage(
        key: state.pageKey,
        child: WebViewComponent(url: url['url']!),
      );
    },
  );
}

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
    child:
        SessionViewScreen(id: state.params['sid'], screenKey: Screen.session),
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
    child: SessionViewScreen(id: state.params['did'], screenKey: Screen.daily),
  );
}

//Can be altered to open other pages in the app other than Downloads (eg Faves)
MaterialPage<void> getCollectionMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: DownloadsListWidget());
}

MaterialPage<void> getPlayerMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: PlayerWidget());
}

MaterialPage<void> getFolderMaterialPage(GoRouterState state) {
  if (state.params.length == 1) {
    return MaterialPage(
        key: state.pageKey, child: FolderView(id: state.params['fid'])
        // child: NewFolderScreen(id: state.params['fid']),
        );
  } else if (state.params.length == 2) {
    return MaterialPage(
        key: state.pageKey, child: FolderView(id: state.params['fid'])
        // child: NewFolderScreen(id: state.params['f2id']),
        );
  } else {
    return MaterialPage(
        key: state.pageKey, child: FolderView(id: state.params['fid'])
        // child: NewFolderScreen(id: state.params['f3id']),
        );
  }
}

String getPathFromString(String? place, List<String?> ids) {
  ids.removeWhere((element) => element == null);

  if (place == 'session') {
    return SessionPath.replaceAll(':sid', ids.first!);
  }
  if (place == 'daily') {
    return DailyPath.replaceAll(':did', ids.first!);
  }
  if (place == 'donation') {
    return DonationPath;
  }
  if (place == 'article') {
    return ArticlePath.replaceAll(':aid', ids.first!);
  }
  if (place != null && place.contains('folder3')) {
    return Folder3Path.replaceAll(':fid', ids.first!)
        .replaceAll(':f2id', ids[1]!)
        .replaceAll(':f3id', ids[2]!);
  }
  if (place != null && place.contains('folder2')) {
    return Folder2Path.replaceAll(':fid', ids.first!)
        .replaceAll(':f2id', ids[1]!);
  }
  if (place == 'folder') {
    return FolderPath.replaceAll(':fid', ids.first!);
  }
  if (place == 'url') {
    launchUrl(ids.first);
  }
  if (place == 'app') {
    return CollectionPath;
  }
  return '';
}
