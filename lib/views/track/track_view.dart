import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/utils/permission_handler.dart';
import 'package:Medito/views/player/player_view.dart';

class TrackView extends ConsumerStatefulWidget {
  final String id;

  TrackView({Key? key, required this.id}) : super(key: key);

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView>{
  TrackAudioModel? selectedAudio;
  TrackFilesModel? selectedDuration;
  final GlobalKey childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var tracks = ref.watch(tracksProvider(trackId: widget.id));

    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: tracks.when(
                  data: (data) => _buildCoverImage(data.coverUrl),
                  loading: () => _buildLoadingCover(),
                  error: (_, __) => _buildErrorCover(),
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: tracks.when(
                  skipLoadingOnRefresh: false,
                  data: (data) => _buildContentWithData(context, data, ref),
                  error: (err, stack) => MeditoErrorWidget(
                    message: err.toString(),
                    onTap: () => ref.refresh(tracksProvider(trackId: widget.id)),
                    isScaffold: false,
                  ),
                  loading: () => _buildLoadingWidget(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: NetworkImageWidget(
        url: url,
        shouldCache: true,
      ),
    );
  }

  Widget _buildLoadingCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(color: Colors.black.withOpacity(0.6)),
    );
  }

  Widget _buildErrorCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(color: Colors.black.withOpacity(0.6)),
    );
  }

  Widget _buildContentWithData(
      BuildContext context,
      TrackModel trackModel,
      WidgetRef ref,
      ) {
    var showGuideNameDropdown =
    trackModel.audio.first.guideName.isNotNullAndNotEmpty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, trackModel.title),
        SizedBox(height: 8),
        _getSubTitle(context, trackModel.description),
        SizedBox(height: 24),
        if (showGuideNameDropdown) ...[
          _guideNameDropdown(trackModel),
          SizedBox(height: 12),
        ],
        _durationDropdown(trackModel),
        SizedBox(height: 12),
        _playBtn(ref, trackModel),
      ],
    );
  }

  Widget _buildLoadingWidget() => const TrackShimmerWidget();

  InkWell _playBtn(WidgetRef ref, TrackModel trackModel) {
    var radius = BorderRadius.all(Radius.circular(7));

    return InkWell(
      onTap: () {
        var file = selectedDuration ?? trackModel.audio.first.files.first;
        _handlePlay(ref, trackModel, file);
      },
      borderRadius: radius,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          color: ColorConstants.walterWhite,
          borderRadius: radius,
        ),
        child: Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: ColorConstants.black,
            size: 32,
          ),
        ),
      ),
    );
  }

  DropdownWidget<TrackFilesModel> _durationDropdown(TrackModel trackModel) {
    var audioFiles = trackModel.audio.first.files;
    var selectedFile = selectedAudio?.files;

    return DropdownWidget<TrackFilesModel>(
      value: selectedDuration ?? audioFiles.first,
      iconData: Icons.timer_sharp,
      topLeft: 7,
      topRight: 7,
      bottomRight: 7,
      bottomLeft: 7,
      isDisabled: (selectedFile ?? audioFiles).length > 1,
      disabledLabelText:
      '${convertDurationToMinutes(milliseconds: audioFiles.first.duration)} ${StringConstants.mins}',
      items: files(selectedFile ?? audioFiles)
          .map<DropdownMenuItem<TrackFilesModel>>(
            (TrackFilesModel value) {
          return DropdownMenuItem<TrackFilesModel>(
            value: value,
            child: Text(
              '${convertDurationToMinutes(milliseconds: value.duration)} ${StringConstants.mins}',
            ),
          );
        },
      ).toList(),
      onChanged: handleOnDurationChange,
    );
  }

  Widget _guideNameDropdown(TrackModel trackModel) {
    var audio = trackModel.audio.first;
    if (audio.guideName.isNotNullAndNotEmpty()) {
      return DropdownWidget<TrackAudioModel>(
        value: selectedAudio ?? audio,
        iconData: Icons.face,
        bottomRight: 7,
        topLeft: 7,
        topRight: 7,
        bottomLeft: 7,
        isDisabled: trackModel.audio.length > 1,
        disabledLabelText: '${audio.guideName}',
        items: trackModel.audio.map<DropdownMenuItem<TrackAudioModel>>(
              (TrackAudioModel value) {
            return DropdownMenuItem<TrackAudioModel>(
              value: value,
              child: Text(value.guideName ?? ''),
            );
          },
        ).toList(),
        onChanged: _handleOnGuideNameChange,
      );
    }

    return SizedBox();
  }

  Text _title(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).primaryTextTheme.titleLarge?.copyWith(
        fontFamily: SourceSerif,
        color: ColorConstants.walterWhite,
        letterSpacing: 0.2,
        fontSize: 24,
      ),
    );
  }

  Widget _getSubTitle(BuildContext context, String? subTitle) {
    if (subTitle != null) {
      var bodyLarge = Theme.of(context).primaryTextTheme.bodyLarge;

      return MarkdownWidget(
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
          fontSize: 16,
        ),
        onTapLink: (text, href, title) {
          handleNavigation(
            TypeConstants.url,
            [href],
            context,
          );
        },
      );
    }

    return SizedBox();
  }

  void _handleOnGuideNameChange(TrackAudioModel? value) {
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
      WidgetRef ref,
      TrackModel trackModel,
      TrackFilesModel file,
      ) async {
    try {
      await PermissionHandler.requestMediaPlaybackPermission(context);

      await ref.read(playerProvider.notifier).loadSelectedTrack(
        trackModel: trackModel,
        file: file,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerView(),
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  List<TrackFilesModel> files(List<TrackFilesModel> files) => files;

}