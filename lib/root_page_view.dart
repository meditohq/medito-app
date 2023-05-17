import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'views/player/components/mini_player_widget.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    ref.read(pageviewNotifierProvider).addListenerToPage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final currentlyPlayingSession = ref.watch(playerProvider);
    var radius = Radius.circular(currentlyPlayingSession != null ? 15 : 0);

    return Scaffold(
      backgroundColor: ColorConstants.almostBlack,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification && scrollNotification.depth == 0) {
            ref
                .read(pageviewNotifierProvider.notifier)
                .updateScrollProportion(scrollNotification);
          }

          return true;
        },
        child: PageView(
          controller: ref.read(pageviewNotifierProvider).pageController,
          scrollDirection: Axis.vertical,
          children: [
            Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: radius,
                      bottomRight: radius,
                    ),
                    child: widget.firstChild,
                  ),
                ),
                if (currentlyPlayingSession != null) height8,
                if (currentlyPlayingSession != null)
                  Consumer(builder: (context, ref, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: radius,
                        topRight: radius,
                      ),
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 700),
                        opacity: ref
                            .watch(pageviewNotifierProvider)
                            .scrollProportion,
                        child: MiniPlayerWidget(
                          sessionModel: currentlyPlayingSession,
                        ),
                      ),
                    );
                  }),
              ],
            ),
            if (currentlyPlayingSession != null)
              PlayerView(
                sessionModel: currentlyPlayingSession,
                file: currentlyPlayingSession.audio.first.files.first,
              ),
          ],
        ),
      ),
    );
  }
}
