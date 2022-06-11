import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/btm_nav/downloads_widget.dart';
import 'package:Medito/widgets/session_options/session_options_screen.dart';
import 'package:Medito/widgets/text/text_file_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/folders/folder_nav_widget.dart';
import '../widgets/home/home_wrapper_widget.dart';
import '../widgets/player/player2/player_widget_2.dart';

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
              GoRoute(
                path: 'folder2/:f2id',
                routes: [
                  _getSessionRoute(),
                  _getArticleRoute(),
                  GoRoute(
                    path: 'folder3/:f3id',
                    pageBuilder: (context, state) =>
                        getFolderMaterialPage(state),
                    routes: [
                      _getSessionRoute(),
                      _getArticleRoute(),
                    ],
                  ),
                ],
                pageBuilder: (context, state) =>
                    getFolderMaterialPage(state),
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
    routes: [
      _getPlayerRoute()
    ],
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
    routes: [
      _getPlayerRoute()
    ],
    pageBuilder: (context, state) => getSessionOptionsMaterialPage(state),
  );
}

GoRoute _getPlayerRoute() {
  return GoRoute(
      path: 'player',
      pageBuilder: (context, state) => getPlayerMaterialPage(state),
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
    child: SessionOptionsScreen(
        id: state.params['sid'], screenKey: Screen.session),
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
    child:
        SessionOptionsScreen(id: state.params['did'], screenKey: Screen.daily),
  );
}

//Can be altered to open other pages in the app other than Downloads (eg Faves)
MaterialPage<void> getCollectionMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: DownloadsListWidget());
}

MaterialPage<void> getPlayerMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: PlayerWidget());
}

MaterialPage<void>? getFolderMaterialPage(GoRouterState state) {
  switch(state.params.length){
    case 1:  return MaterialPage(
        key: state.pageKey, child: FolderNavWidget(id: state.params['fid']));
    case 2:  return MaterialPage(
        key: state.pageKey, child: FolderNavWidget(id: state.params['f2id']));
    case 3:  return MaterialPage(
        key: state.pageKey, child: FolderNavWidget(id: state.params['f3id']));
    default: return null;
  }

}

String getPathFromString(String? place, List<String> ids) {
  if (place == 'session') {
    return SessionPath.replaceAll(':sid', ids.first);
  }
  if (place == 'daily') {
    return DailyPath.replaceAll(':did', ids.first);
  }
  if (place == 'donation') {
    return DonationPath;
  }
  if (place == 'article') {
    return ArticlePath.replaceAll(':aid', ids.first);
  }
  if (place != null && place.contains('folder3')) {
    return Folder3Path.replaceAll(':fid', ids.first).replaceAll(':f2id', ids[1])
        .replaceAll(':f3id', ids[2]);
  }
  if (place != null && place.contains('folder2')) {
    return Folder2Path.replaceAll(':fid', ids.first)
        .replaceAll(':f2id', ids[1]);
  }
  if (place == 'folder') {
    return FolderPath.replaceAll(':fid', ids.first);
  }
  if (place == 'url') {
    launchUrl(ids.first);
  }
  if (place == 'app') {
    return CollectionPath;
  }
  return '';
}
