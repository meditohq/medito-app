import 'package:Medito/components/components.dart';
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
import 'package:Medito/views/home/home_view.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:Medito/views/meditation/meditation_view.dart';
import 'package:Medito/views/splash_view.dart';
import 'package:Medito/views/text/text_file_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/home_old/home_wrapper_widget.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: _rootNavigatorKey,
  initialLocation: RouteConstants.homePath,
  routes: [
    // GoRoute(
    //   path: RouteConstants.root,
    //   pageBuilder: (context, state) => MaterialPage(
    //     key: state.pageKey,
    //     child: SplashView(),
    //   ),
    // ),
    // GoRoute(
    //   path: RouteConstants.joinIntroPath,
    //   pageBuilder: (context, state) => MaterialPage(
    //     key: state.pageKey,
    //     child: JoinIntroView(),
    //   ),
    // ),
    // GoRoute(
    //   path: RouteConstants.joinEmailPath,
    //   pageBuilder: (context, state) => MaterialPage(
    //     key: state.pageKey,
    //     child: JoinEmailView(),
    //   ),
    // ),
    // GoRoute(
    //   path: RouteConstants.joinVerifyOTPPath,
    //   pageBuilder: (context, state) {
    //     final data = state.extra! as Map;

    //     return MaterialPage(
    //       key: state.pageKey,
    //       child: JoinVerifyOTPView(email: data['email']!),
    //     );
    //   },
    // ),
    // GoRoute(
    //   path: RouteConstants.joinWelcomePath,
    //   pageBuilder: (context, state) {
    //     final data = state.extra! as Map;

    //     return MaterialPage(
    //       key: state.pageKey,
    //       child: JoinWelcomeView(
    //         email: data['email']!,
    //       ),
    //     );
    //   },
    // ),
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
            // child: HomeWrapperWidget(),
            child: HomeView(),
          ),
        ),
        _getMeditationRoute(fromRoot: true),
        _getArticleRoute(fromRoot: true),
        _getDailyRoute(fromRoot: true),
        _getWebviewRoute(fromRoot: true),
        _getBackgroundSoundRoute(),
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
            _getMeditationRoute(),
            _getArticleRoute(),
            _getWebviewRoute(),
            GoRoute(
              path: 'folder2/:f2id',
              routes: [
                _getMeditationRoute(),
                _getArticleRoute(),
                _getWebviewRoute(),
                GoRoute(
                  path: 'folder3/:f3id',
                  pageBuilder: (context, state) => getFolderMaterialPage(state),
                  routes: [
                    _getMeditationRoute(),
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
    path: fromRoot
        ? RouteConstants.dailyPath
        : RouteConstants.dailyPath.sanitisePath(),
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getMeditationOptionsDailyPage(state),
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

GoRoute _getMeditationRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.meditationPath
        : RouteConstants.meditationPath.sanitisePath(),
    routes: [_getPlayerRoute()],
    pageBuilder: (context, state) => getMeditationOptionsMaterialPage(state),
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
    path: fromRoot
        ? RouteConstants.webviewPath
        : RouteConstants.webviewPath.sanitisePath(),
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
  meditation,
  daily,
  donation,
  url,
  collection
}

MaterialPage<void> getMeditationOptionsMaterialPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: MeditationView(id: state.params['sid'], screenKey: Screen.meditation),
  );
}

MaterialPage<void> getArticleMaterialPAge(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: TextFileWidget(id: state.params['aid']),
  );
}

MaterialPage<void> getMeditationOptionsDailyPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: MeditationView(id: state.params['did'], screenKey: Screen.daily),
  );
}

//Can be altered to open other pages in the app other than Downloads (eg Faves)
MaterialPage<void> getCollectionMaterialPage(GoRouterState state) {
  return MaterialPage(key: state.pageKey, child: DownloadsView());
}

MaterialPage<void> getPlayerMaterialPage(GoRouterState state) {
  var meditation = state.extra as Map;

  return MaterialPage(
    key: state.pageKey,
    child: PlayerView(
      meditationModel: meditation['meditationModel'],
      file: meditation['file'],
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

  if (place == 'meditation') {
    return RouteConstants.meditationPath.replaceAll(':sid', ids.first!);
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
    launchUrl(ids.first);
  }
  if (place == 'app') {
    return RouteConstants.collectionPath;
  }

  return '';
}
