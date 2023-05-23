import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/artist_title_component.dart';
import 'components/background_image_component.dart';
import 'components/bottom_actions/bottom_action_component.dart';
import 'components/duration_indicator_component.dart';
import 'components/overlay_cover_image_component.dart';
import 'components/player_buttons/player_buttons_component.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key, required this.meditationModel, required this.file});
  final MeditationModel meditationModel;
  final MeditationFilesModel file;
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView>
    with AutomaticKeepAliveClientMixin<PlayerView> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var coverUrl = widget.meditationModel.coverUrl;
    var artist = widget.meditationModel.artist;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: false,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            BackgroundImageComponent(imageUrl: coverUrl),
            SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: ColorConstants.walterWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 4.0,
                    ),
                    child: ArtistTitleComponent(
                      meditationTitle: widget.meditationModel.title,
                      artistName: artist?.name,
                      artistUrlPath: artist?.path,
                    ),
                  ),
                  OverlayCoverImageComponent(imageUrl: coverUrl),
                  DurationIndicatorComponent(file: widget.file),
                  Spacer(),
                  PlayerButtonsComponent(
                    file: widget.file,
                    meditationModel: widget.meditationModel,
                  ),
                  Spacer(),
                  BottomActionComponent(
                    meditationModel: widget.meditationModel,
                    file: widget.file,
                  ),
                  height16,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (ref.read(pageviewNotifierProvider).currentPage == 1) {
      ref.read(pageviewNotifierProvider).gotoPreviousPage();

      return false;
    }

    return true;
  }

  @override
  bool get wantKeepAlive => true;
}
