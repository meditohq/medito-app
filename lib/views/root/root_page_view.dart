import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/providers/root/root_combine_provider.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/views/root/widgets/big_player_widget.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/sticky_mini_player_widget.dart';

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
    ref.listen(
      playerProvider,
      (prev, next) {
        var prevId = prev?.audio.first.files.first.id;
        var nextId = next?.audio.first.files.first.id;
        if (next != null &&
            (prev?.id != next.id ||
                (prev?.id == next.id && prevId != nextId))) {
          ref.read(playerProvider.notifier).handleAudioStartedEvent(
                next.id,
                next.audio.first.files.first.id,
              );
        }
      },
    );

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
          physics: ClampingScrollPhysics(),
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                _renderChild(
                  context,
                  connectivityStatus as ConnectivityStatus,
                ),
                StickyMiniPlayerWidget(),
              ],
            ),
            BigPlayerWidget(),
          ],
        ),
      ),
    );
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
