import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notifications/notifications_service.dart';
import 'widgets/widgets.dart';
import 'views/player/widgets/mini_player_widget.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    ref.read(deviceAndAppInfoProvider);
    ref.read(remoteStatsProvider);
    ref.read(postLocalStatsProvider);
    ref.read(pageviewNotifierProvider).addListenerToPage();
    requestPermission();
    ref.read(playerProvider.notifier).getCurrentlyPlayingMeditation();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    final currentlyPlayingSession = ref.watch(playerProvider);
    ref.listen(playerProvider, (prev, next) {
      var prevId = prev?.audio.first.files.first.id;
      var nextId = next?.audio.first.files.first.id;
      if (next != null &&
          (prev?.id != next.id || (prev?.id == next.id && prevId != nextId))) {
        _handleTrackEvent(
          ref,
          next.id,
          next.audio.first.files.first.id,
        );
      }
    });
    var radius = Radius.circular(currentlyPlayingSession != null ? 15 : 0);
    if (connectivityStatus == ConnectivityStatus.isDisonnected) {
      return ConnectivityErrorWidget();
    }

    return Scaffold(
      backgroundColor: ColorConstants.almostBlack,
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
                          meditationModel: currentlyPlayingSession,
                        ),
                      ),
                    );
                  }),
              ],
            ),
            if (currentlyPlayingSession != null)
              PlayerView(
                meditationModel: currentlyPlayingSession,
                file: currentlyPlayingSession.audio.first.files.first,
              ),
          ],
        ),
      ),
    );
  }

  void _handleTrackEvent(
    WidgetRef ref,
    int meditationId,
    int audioFileId,
  ) {
    var audio =
        AudioStartedModel(audioFileId: audioFileId, meditationId: meditationId);
    var event = EventsModel(
      name: EventTypes.audioStarted,
      payload: audio.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
