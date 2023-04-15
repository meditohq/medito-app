import 'package:Medito/constants/constants.dart';
import 'package:Medito/view_model/page_view/page_view_viewmodel.dart';
import 'package:Medito/view_model/player/player_viewmodel.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'views/player/components/mini_player_widget.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});
  @override
  ConsumerState<RootPageView> createState() => _RootPageViewtState();
}

class _RootPageViewtState extends ConsumerState<RootPageView> {
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
      body: PageView(
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
                    child: AnimatedCrossFade(
                      duration: Duration(milliseconds: 700),
                      crossFadeState:
                          ref.watch(pageviewNotifierProvider).currentPage == 0
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                      firstChild: MiniPlayerWidget(
                        sessionModel: currentlyPlayingSession,
                      ),
                      secondChild: Container(
                        height: 64,
                        color: ColorConstants.greyIsTheNewGrey,
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
    );
  }
}
