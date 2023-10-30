import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
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
    required this.trackModel,
    required this.file,
  });
  final TrackModel trackModel;
  final TrackFilesModel file;
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
    var coverUrl = widget.trackModel.coverUrl;
    var artist = widget.trackModel.artist;

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
                        Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 4.0,
                          ),
                          child: ArtistTitleWidget(
                            trackTitle: widget.trackModel.title,
                            artistName: artist?.name,
                            artistUrlPath: artist?.path,
                            isPlayerScreen: true,
                          ),
                        ),
                        OverlayCoverImageWidget(imageUrl: coverUrl),
                        DurationIndicatorWidget(
                          file: widget.file,
                          trackId: widget.trackModel.id,
                        ),
                        Spacer(),
                        PlayerButtonsWidget(
                          file: widget.file,
                          trackModel: widget.trackModel,
                        ),
                        Spacer(
                          flex: 2,
                        ),
                        BottomActionWidget(
                          trackModel: widget.trackModel,
                          file: widget.file,
                        ),
                        height16,
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

      print(_opacity);
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
