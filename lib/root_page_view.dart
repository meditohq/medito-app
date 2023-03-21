import 'package:Medito/constants/colors/color_constants.dart';
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
    ref.read(playerProvider.notifier).getCurrentlyPlayingSession();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final currentlyPlayingSession = ref.watch(playerProvider);
    return Scaffold(
      backgroundColor: ColorConstants.greyIsTheNewGrey,
      body: PageView(
        controller: ref.read(pageviewNotifierProvider).pageController,
        scrollDirection: Axis.vertical,
        physics: BouncingScrollPhysics(),
        children: [
          Column(
            children: [
              Expanded(child: widget.firstChild),
              if (currentlyPlayingSession != null)
                MiniPlayerWidget(
                  sessionModel: currentlyPlayingSession,
                )
            ],
          ),
          if (currentlyPlayingSession != null)
            PlayerView(
                sessionModel: currentlyPlayingSession,
                file: currentlyPlayingSession.audio.first.files.first)
        ],
      ),
    );
  }
}
