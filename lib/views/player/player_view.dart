import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/artist_title_widget.dart';
import 'widgets/background_image_widget.dart';
import 'widgets/bottom_actions/bottom_action_widget.dart';
import 'widgets/duration_indicator_widget.dart';
import 'widgets/overlay_cover_image_widget.dart';
import 'widgets/player_buttons/player_buttons_widget.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({
    super.key,
  });
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView>
    with AutomaticKeepAliveClientMixin {
  double _dragStartY = 0.0;
  double _currentY = 0.0;
  final _currentX = 0.0;
  double _opacity = 1.0;
  String heroTag = 'swipe-down-to-close';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var currentlyPlayingTrack = ref.watch(playerProvider);
    if (currentlyPlayingTrack == null) {
      return MeditoErrorWidget(
        onTap: () => context.pop(),
        message: StringConstants.unableToLoadAudio,
      );
    }
    var coverUrl = currentlyPlayingTrack.coverUrl;
    var artist = currentlyPlayingTrack.artist;
    var file = currentlyPlayingTrack.audio.first.files.first;

    return GestureDetector(
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Hero(
        tag: heroTag,
        child: Transform(
          transform: Matrix4.translationValues(_currentX, _currentY, 0),
          child: Opacity(
            opacity: _opacity,
            child: Scaffold(
              extendBody: true,
              extendBodyBehindAppBar: true,
              body: Stack(
                children: [
                  BackgroundImageWidget(imageUrl: coverUrl),
                  SafeArea(
                    child: Column(
                      children: [
                        height16,
                        HandleBarWidget(),
                        height8,
                        OverlayCoverImageWidget(imageUrl: coverUrl),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                          ),
                          child: ArtistTitleWidget(
                            trackTitle: currentlyPlayingTrack.title,
                            artistName: artist?.name,
                            artistUrlPath: artist?.path,
                            isPlayerScreen: true,
                          ),
                        ),
                        DurationIndicatorWidget(
                          file: file,
                          trackId: currentlyPlayingTrack.id,
                        ),
                        Spacer(),
                        Transform.translate(
                          offset: Offset(0, -20), // adjust the value as needed
                          child: PlayerButtonsWidget(
                            file: file,
                            trackModel: currentlyPlayingTrack,
                          ),
                        ),
                        Spacer(),
                        BottomActionWidget(
                          trackModel: currentlyPlayingTrack,
                          file: file,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    var dragDistance = details.globalPosition.dy - _dragStartY;
    if (dragDistance > 0) {
      var calculatedOpacity = 1 - (dragDistance / 400);
      if (calculatedOpacity < 0) {
        calculatedOpacity = 0.05;
      } else if (calculatedOpacity > 1) {
        calculatedOpacity = 1;
      }
      setState(() {
        _currentY = dragDistance;
        _opacity = calculatedOpacity.toDouble();
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    if (_currentY > 200) {
      context.pop();
    } else {
      setState(() {
        _currentY = 0;
        _opacity = 1.0;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;
}
