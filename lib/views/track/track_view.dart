/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'dart:async';

import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TrackView extends ConsumerStatefulWidget {
  final String id;

  TrackView({Key? key, required this.id}) : super(key: key);

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView>
    with AutomaticKeepAliveClientMixin<TrackView> {
  TrackAudioModel? selectedAudio;
  TrackFilesModel? selectedDuration;

  @override
  void initState() {
    _handleTrackEvent(ref, widget.id);
    super.initState();
  }

  void _handleTrackEvent(WidgetRef ref, String trackId) {
    var trackViewedModel = TrackViewedModel(trackId: trackId);
    var event = EventsModel(
      name: EventTypes.trackViewed,
      payload: trackViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  void handleOnArtistChange(TrackAudioModel? value) {
    setState(() {
      selectedAudio = value;
      selectedDuration = value?.files.first;
    });
  }

  void handleOnDurationChange(TrackFilesModel? value) {
    setState(() {
      selectedDuration = value;
    });
  }

  void _handlePlay(
    BuildContext context,
    WidgetRef ref,
    TrackModel trackModel,
    TrackFilesModel file,
  ) async {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    audioProvider.clearAssetCache();
    await ref
        .read(playerProvider.notifier)
        .addCurrentlyPlayingTrackInPreference(
          trackModel: trackModel,
          file: file,
        );
    unawaited(context.push(RouteConstants.playerPath));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(trackOpenedFirstTimeProvider);
    var tracks = ref.watch(tracksProvider(trackId: widget.id));
    ref.listen(trackOpenedFirstTimeProvider, (prev, next) {
      var _user =
          ref.read(authProvider.notifier).userRes.body as UserTokenModel;
      if (_user.email == null && next.value != null && next.value!) {
        var params = JoinRouteParamsModel(screen: Screen.track);
        context.push(
          RouteConstants.joinIntroPath,
          extra: params,
        );
      }
    });

    return tracks.when(
      skipLoadingOnRefresh: false,
      data: (data) => _buildScaffoldWithData(context, data, ref),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(tracksProvider(trackId: widget.id)),
      ),
      loading: () => _buildLoadingWidget(),
    );
  }

  TrackShimmerWidget _buildLoadingWidget() => const TrackShimmerWidget();

  Widget _buildScaffoldWithData(
    BuildContext context,
    TrackModel trackModel,
    WidgetRef ref,
  ) {
    return Container(
      padding: EdgeInsets.only(bottom: getBottomPadding(context)),
      child: SingleChildScrollView(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                fit: StackFit.passthrough,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 248,
                      child: NetworkImageWidget(
                        url: trackModel.coverUrl,
                        isCache: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: HandleBarWidget(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    height32,
                    _title(context, trackModel.title),
                    _getSubTitle(context, trackModel.description),
                    height32,
                    Row(
                      children: [
                        _artist(trackModel),
                        _duration(trackModel),
                      ],
                    ),
                    height12,
                    _playBtn(context, ref, trackModel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InkWell _playBtn(BuildContext context, WidgetRef ref, TrackModel trackModel) {
    var radius = BorderRadius.only(
      topLeft: Radius.circular(7),
      topRight: Radius.circular(7),
      bottomRight: Radius.circular(24),
      bottomLeft: Radius.circular(24),
    );

    return InkWell(
      onTap: () {
        var _file = selectedDuration ?? trackModel.audio.first.files.first;
        _handlePlay(context, ref, trackModel, _file);
      },
      borderRadius: radius,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          color: ColorConstants.walterWhite,
          borderRadius: radius,
        ),
        child: Center(
          child: Text(
            StringConstants.play,
            style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(
                  color: ColorConstants.black,
                  fontFamily: ClashDisplay,
                  height: 0,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Flexible _duration(TrackModel trackModel) {
    var audioFiles = trackModel.audio.first.files;
    var _selectedFile = selectedAudio?.files;

    return Flexible(
      child: DropdownWidget<TrackFilesModel>(
        value: selectedDuration ?? audioFiles.first,
        iconData: Icons.timer_sharp,
        bottomRight: 7,
        disabled: audioFiles.length > 1,
        disabledLabelText:
            '${convertDurationToMinutes(milliseconds: audioFiles.first.duration)} mins',
        items: files(_selectedFile ?? audioFiles)
            .map<DropdownMenuItem<TrackFilesModel>>(
          (TrackFilesModel value) {
            return DropdownMenuItem<TrackFilesModel>(
              value: value,
              child: Text(
                '${convertDurationToMinutes(milliseconds: value.duration)} mins',
              ),
            );
          },
        ).toList(),
        onChanged: handleOnDurationChange,
      ),
    );
  }

  Widget _artist(TrackModel trackModel) {
    var audio = trackModel.audio.first;
    if (audio.guideName.isNotNullAndNotEmpty()) {
      return Flexible(
        child: Row(
          children: [
            Flexible(
              child: DropdownWidget(
                value: selectedAudio ?? audio,
                iconData: Icons.face,
                bottomLeft: 7,
                disabled: trackModel.audio.length > 1,
                disabledLabelText: '${audio.guideName}',
                items: trackModel.audio.map<DropdownMenuItem<TrackAudioModel>>(
                  (TrackAudioModel value) {
                    return DropdownMenuItem<TrackAudioModel>(
                      value: value,
                      child: Text(value.guideName ?? ''),
                    );
                  },
                ).toList(),
                onChanged: handleOnArtistChange,
              ),
            ),
            width12,
          ],
        ),
      );
    }

    return SizedBox();
  }

  List<TrackFilesModel> files(List<TrackFilesModel> files) => files;

  Text _title(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).primaryTextTheme.titleLarge?.copyWith(
            fontFamily: ClashDisplay,
            color: ColorConstants.walterWhite,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            fontSize: 24,
          ),
    );
  }

  Widget _getSubTitle(BuildContext context, String? subTitle) {
    if (subTitle != null) {
      var bodyLarge = Theme.of(context).primaryTextTheme.bodyLarge;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          height8,
          MarkdownWidget(
            body: subTitle,
            selectable: true,
            textAlign: WrapAlignment.start,
            p: bodyLarge?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              fontSize: 16,
            ),
            a: bodyLarge?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              decoration: TextDecoration.underline,
            ),
            onTapLink: (text, href, title) {
              context.pop();
              var location = GoRouter.of(context).location;
              context.push(
                location + RouteConstants.webviewPath,
                extra: {'url': href},
              );
            },
          ),
        ],
      );
    }

    return SizedBox();
  }

  @override
  bool get wantKeepAlive => true;
}
