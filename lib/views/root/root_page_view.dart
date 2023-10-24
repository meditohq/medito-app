import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/providers/root/root_combine_provider.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:Medito/views/player/widgets/mini_player_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    ref.read(rootCombineProvider(context));
    ref.read(checkNotificationPermissionProvider(context));
    checkInitialMessage(ref);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    final currentlyPlayingSession = ref.watch(playerProvider);
    var radius = Radius.circular(currentlyPlayingSession != null ? 15 : 0);
    ref.listen(playerProvider, (prev, next) {
      var prevId = prev?.audio.first.files.first.id;
      var nextId = next?.audio.first.files.first.id;
      if (next != null &&
          (prev?.id != next.id || (prev?.id == next.id && prevId != nextId))) {
        ref.read(playerProvider.notifier).handleAudioStartedEvent(
              next.id,
              next.audio.first.files.first.id,
            );
      }
    });

    return Scaffold(
      backgroundColor: ColorConstants.black,
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification &&
              scrollNotification.depth == 0) {
            ref
                .read(pageviewNotifierProvider.notifier)
                .updateScrollProportion(scrollNotification);
          }

          return true;
        },
        child: PageView(
          controller: ref.read(pageviewNotifierProvider).pageController,
          scrollDirection: Axis.vertical,
          // physics: NeverScrollableScrollPhysics(),
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: radius,
                    bottomRight: radius,
                  ),
                  child: _renderChild(
                    context,
                    connectivityStatus as ConnectivityStatus,
                  ),
                ),
                _miniPlayer(radius, currentlyPlayingSession),
              ],
            ),
            if (currentlyPlayingSession != null)
              PlayerView(
                trackModel: currentlyPlayingSession,
                file: currentlyPlayingSession.audio.first.files.first,
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniPlayer(Radius radius, TrackModel? currentlyPlayingSession) {
    var opacity = ref.watch(pageviewNotifierProvider).scrollProportion;
    var bottom = getBottomPadding(context) + 8;
    if (currentlyPlayingSession != null) {
      return Consumer(
        builder: (context, ref, child) {
          return Dismissible(
            key: UniqueKey(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: bottom,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.all(radius),
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 700),
                  opacity: opacity,
                  child: MiniPlayerWidget(
                    trackModel: currentlyPlayingSession,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return SizedBox();
  }

  Widget _renderChild(BuildContext context, ConnectivityStatus status) {
    var location = GoRouter.of(context).location;
    if (location == RouteConstants.downloadsPath) {
      return widget.firstChild;
    } else if (status == ConnectivityStatus.isDisonnected) {
      return ConnectivityErrorWidget();
    } else {
      return widget.firstChild;
    }
  }
}
