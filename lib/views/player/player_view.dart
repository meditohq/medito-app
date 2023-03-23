import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:Medito/view_model/player/download/audio_downloader_viewmodel.dart';
import 'package:Medito/view_model/player/audio_play_pause_viewmodel.dart';
import 'package:Medito/view_model/player/player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/artist_title_component.dart';
import 'components/background_image_component.dart';
import 'components/bottom_actions/bottom_action_component.dart';
import 'components/duration_indicatior_component.dart';
import 'components/overlay_cover_image_component.dart';
import 'components/player_buttons_component.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key, required this.sessionModel, required this.file});
  final SessionModel sessionModel;
  final SessionFilesModel file;
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView>
    with AutomaticKeepAliveClientMixin<PlayerView> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          BackgroundImageComponent(imageUrl: widget.sessionModel.coverUrl),
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
                ArtistTitleComponent(sessionModel: widget.sessionModel),
                OverlayCoverImageComponent(
                    imageUrl: widget.sessionModel.coverUrl),
                DurationIndicatorComponent(file: widget.file),
                Spacer(),
                PlayerButtonsComponent(
                  file: widget.file,
                  sessionModel: widget.sessionModel,
                ),
                Spacer(),
                BottomActionComponent(
                  sessionModel: widget.sessionModel,
                  file: widget.file,
                ),
                height16,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
