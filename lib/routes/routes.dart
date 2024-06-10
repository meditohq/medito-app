import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/background_sound/background_sound_view.dart';
import 'package:Medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:Medito/views/downloads/downloads_view.dart';
import 'package:Medito/views/end_screen/end_screen_view.dart';
import 'package:Medito/views/explore/explore_view.dart';
import 'package:Medito/views/home/home_view.dart';
import 'package:Medito/views/maintenance/maintenance_view.dart';
import 'package:Medito/views/missing_route/missing_route_view.dart';
import 'package:Medito/views/notifications/notification_permission_view.dart';
import 'package:Medito/views/pack/pack_view.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:Medito/views/root/root_page_view.dart';
import 'package:Medito/views/splash_view.dart';
import 'package:Medito/views/track/track_view.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/maintenance/maintenance_model.dart';

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
  errorBuilder: (context, state) {
    return MissingRouteView();
  },
  routes: [
    GoRoute(
      path: RouteConstants.root,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: SplashView(),
      ),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => RootPageView(
        firstChild: child,
      ),
      routes: [
        _getMaintenanceRoute(),
        _getBottomNavigationBarRoute(),
        _getHomeRoute(),
        _getTrackRoute(fromRoot: true),
        _getConnectivityErrorRoute(fromRoot: true),
        _getDownloadsRoute(fromRoot: true),
        _getExploreRoute(fromRoot: true),
        GoRoute(
          path: RouteConstants.packPath,
          routes: [
            _getTrackRoute(),
            GoRoute(
              path: 'pack2/:p2id',
              routes: [
                _getTrackRoute(),
                GoRoute(
                  path: 'pack3/:p3id',
                  pageBuilder: (context, state) =>
                      _getFolderMaterialPage(state),
                  routes: [
                    _getTrackRoute(),
                  ],
                ),
              ],
              pageBuilder: (context, state) => _getFolderMaterialPage(state),
            ),
          ],
          pageBuilder: (context, state) => _getFolderMaterialPage(state),
        ),
      ],
    ),
    _getBackgroundSoundRoute(),
    _getNotificationPermissionRoute(),
    _getPlayerRoute(fromRoot: true),
    _getEndScreenRoute(fromRoot: true),
  ],
);

GoRoute _getHomeRoute() {
  return GoRoute(
    path: RouteConstants.homePath,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: HomeView(),
    ),
    routes: [
      _getDownloadsRoute(),
    ],
  );
}

GoRoute _getBottomNavigationBarRoute() {
  return GoRoute(
    path: RouteConstants.bottomNavbarPath,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: BottomNavigationBarView(),
    ),
  );
}

GoRoute _getTrackRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.trackPath
        : RouteConstants.trackPath.sanitisePath(),
    pageBuilder: (context, state) => _getTrackOptionsMaterialPage(state),
  );
}

GoRoute _getPlayerRoute({bool fromRoot = false}) {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: fromRoot
        ? RouteConstants.playerPath
        : RouteConstants.playerPath.sanitisePath(),
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: PlayerView(),
      );
    },
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

GoRoute _getExploreRoute({bool fromRoot = false}) {
  return GoRoute(
    path: fromRoot
        ? RouteConstants.explorePath
        : RouteConstants.explorePath.sanitisePath(),
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: ExploreView(),
      );
    },
  );
}

GoRoute _getEndScreenRoute({bool fromRoot = false}) {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: fromRoot
        ? RouteConstants.endScreenPath
        : RouteConstants.endScreenPath.sanitisePath(),
    pageBuilder: (context, state) {
      final params = state.extra as TrackModel;

      return MaterialPage(
        key: state.pageKey,
        child: EndScreenView(
          trackModel: params,
        ),
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
    routes: [
      _getPlayerRoute(),
    ],
  );
}

GoRoute _getMaintenanceRoute() {
  return GoRoute(
    parentNavigatorKey: _shellNavigatorKey,
    path: RouteConstants.maintenancePath,
    pageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child:
            MaintenanceView(maintenanceModel: state.extra as MaintenanceModel),
      );
    },
  );
}

MaterialPage<void> _getTrackOptionsMaterialPage(GoRouterState state) {
  return MaterialPage(
    key: state.pageKey,
    child: TrackView(id: state.params['sid'] ?? ''),
  );
}

MaterialPage<void> _getFolderMaterialPage(GoRouterState state) {
  var packId =
      state.params['p3id'] ?? state.params['p2id'] ?? state.params['pid'];

  return MaterialPage(
    key: state.pageKey,
    child: PackView(id: packId ?? ''),
  );
}

Future<void> handleNavigation(
  String? place,
  List<String?> ids,
  BuildContext context, {
  WidgetRef? ref,
}) async {
  var path;
  ids.removeWhere((element) => element == null);
  if (place != null && 'tracks'.contains(place)) {
    try {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24.0),
            ),
          ),
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: ColorConstants.ebony,
          builder: (BuildContext context) {
            return SafeArea(
              child: TrackView(
                id: ids.first!,
              ),
            );
          },
        ).then(
          (value) => ref?.refresh(fetchStatsProvider),
        ),
      );
    } catch (e, s) {
      print(s);
    }

    return;
  } else if (place != null && place.contains('pack3')) {
    path = RouteConstants.pack3Path
        .replaceAll(':pid', ids.first!)
        .replaceAll(':p2id', ids[1]!)
        .replaceAll(':p3id', ids[2]!);
  } else if (place != null && place.contains('pack2')) {
    path = RouteConstants.pack2Path
        .replaceAll(':pid', ids.first!)
        .replaceAll(':p2id', ids[1]!);
  } else if (place == TypeConstants.pack) {
    path = RouteConstants.packPath.replaceAll(':pid', ids.first!);
  } else if (place == TypeConstants.url || place == TypeConstants.link) {
    await launchURLInBrowser(ids.last ?? StringConstants.meditoUrl);

    return;
  } else if (place == TypeConstants.flow) {
    path = '/${ids.first}';
  } else if (place == TypeConstants.email) {
    if (ref != null) {
      var deviceAppAndUserInfo =
          await ref.read(deviceAppAndUserInfoProvider.future);
      var _info =
          '${StringConstants.debugInfo}\n$deviceAppAndUserInfo\n${StringConstants.writeBelowThisLine}';

      path = ids.first;

      await launchEmailSubmission(
        path.toString(),
        body: _info,
      );
    }

    return;
  }
  unawaited(context.push(path));
}

void handleDeepLink(Uri? uri, BuildContext context) {
  var path = uri?.path;
  if (path != null) {
    if (path.contains('tracks')) {
      handleNavigation(
        'tracks',
        [uri?.pathSegments.last ?? ''],
        context,
      );
    } else {
      unawaited(context.push(path));
    }
  }
}
