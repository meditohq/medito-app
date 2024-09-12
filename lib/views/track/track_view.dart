import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/player/widgets/bottom_actions/back_and_fave_action_bar.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/meditation/track_provider.dart';

class TrackView extends ConsumerStatefulWidget {
  final String trackId;

  const TrackView({Key? key, required this.trackId}) : super(key: key);

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView> {
  TrackAudioModel? selectedAudio;
  TrackFilesModel? fileModel;
  final GlobalKey _contentKey = GlobalKey();
  bool _useCompactLayout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
      _initializeFileModel();
    });
  }

  void _initializeFileModel() {
    var tracks = ref.read(tracksProvider(trackId: widget.trackId));
    tracks.whenData((trackModel) {
      if (trackModel.audio.isNotEmpty &&
          trackModel.audio.first.files.isNotEmpty) {
        setState(() {
          fileModel = trackModel.audio.first.files.first;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trackAsyncValue = ref.watch(tracksProvider(trackId: widget.trackId));

    return Scaffold(
      bottomNavigationBar: trackAsyncValue.when(
        data: (trackModel) => TrackViewBottomBar(
          trackId: widget.trackId,
          onBackPressed: () => Navigator.pop(context),
        ),
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: trackAsyncValue.when(
                  data: (trackModel) => orientation == Orientation.portrait
                      ? _buildPortraitLayout(trackAsyncValue)
                      : _buildLandscapeLayout(trackAsyncValue),
                  loading: () => _buildLoadingWidget(),
                  error: (err, stack) => MeditoErrorWidget(
                    message: err.toString(),
                    onTap: () =>
                        ref.refresh(tracksProvider(trackId: widget.trackId)),
                    isScaffold: false,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _checkOverflow() {
    final renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final screenHeight = MediaQuery.of(context).size.height;
      final contentHeight = size.height;

      setState(() {
        _useCompactLayout = contentHeight > screenHeight;
      });
    }
  }

  Widget _buildPortraitLayout(AsyncValue<TrackModel> tracks) {
    return Column(
      key: _contentKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildCoverImage(tracks),
        ),
        const SizedBox(height: 24),
        _buildTrackContent(tracks, isLandscape: false),
      ],
    );
  }

  Widget _buildLandscapeLayout(AsyncValue<TrackModel> tracks) {
    var size = MediaQuery.of(context).size;
    var maxWidth = size.width * 0.25;
    var maxHeight = size.height * 0.45;

    return Column(
      key: _contentKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildCoverImage(tracks),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: tracks.when(
                data: (data) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(context, data.title),
                        const SizedBox(height: 8),
                        _getSubTitle(
                          context,
                          data.description,
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => _buildLoadingWidget(),
                error: (err, stack) => MeditoErrorWidget(
                  message: err.toString(),
                  onTap: () =>
                      ref.refresh(tracksProvider(trackId: widget.trackId)),
                  isScaffold: false,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTrackContent(tracks, isLandscape: true),
      ],
    );
  }

  Widget _buildCoverImage(AsyncValue<TrackModel> tracks) {
    return tracks.when(
      data: (data) => _buildImageWithData(data.coverUrl),
      loading: () => _buildLoadingCover(),
      error: (_, __) => _buildErrorCover(),
    );
  }

  Widget _buildImageWithData(String url) {
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

  Widget _buildTrackContent(
    AsyncValue<TrackModel> tracks, {
    required bool isLandscape,
  }) {
    return tracks.when(
      skipLoadingOnRefresh: false,
      data: (data) =>
          _buildContentWithData(context, data, ref, isLandscape: isLandscape),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(tracksProvider(trackId: widget.trackId)),
        isScaffold: false,
      ),
      loading: () => _buildLoadingWidget(),
    );
  }

  Widget _buildContentWithData(
    BuildContext context,
    TrackModel trackModel,
    WidgetRef ref, {
    required bool isLandscape,
  }) {
    var showGuideNameDropdown =
        trackModel.audio.first.guideName.isNotNullAndNotEmpty();

    return isLandscape
        ? Row(children: [
            if (showGuideNameDropdown)
              Expanded(child: _guideNameDropdown(trackModel, isLandscape: true))
            else
              const Spacer(),
            const SizedBox(width: 12),
            Expanded(child: _durationDropdown(trackModel, isLandscape: true)),
            const SizedBox(width: 12),
            Expanded(child: _playBtn(ref, trackModel, isFullWidth: false)),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title(context, trackModel.title),
            const SizedBox(height: 8),
            _getSubTitle(context, trackModel.description),
            const SizedBox(height: 24),
            if (_useCompactLayout && showGuideNameDropdown)
              _buildCompactPickers(trackModel)
            else ...[
              if (showGuideNameDropdown) ...[
                _guideNameDropdown(trackModel, isLandscape: false),
                const SizedBox(height: 12),
              ],
              _durationDropdown(trackModel, isLandscape: false),
            ],
            const SizedBox(height: 12),
            _playBtn(ref, trackModel, isFullWidth: true),
          ]);
  }

  Widget _buildCompactPickers(TrackModel trackModel) {
    return Row(
      children: [
        Expanded(
          child: _guideNameDropdown(trackModel, isLandscape: false),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _durationDropdown(trackModel, isLandscape: false),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() => const TrackShimmerWidget();

  Widget _playBtn(
    WidgetRef ref,
    TrackModel trackModel, {
    required bool isFullWidth,
  }) {
    var radius = const BorderRadius.all(Radius.circular(7));

    return InkWell(
      onTap: () {
        var file = fileModel ?? trackModel.audio.first.files.first;
        _handlePlay(ref, trackModel, file);
      },
      borderRadius: radius,
      child: Ink(
        height: 56,
        width: isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: ColorConstants.walterWhite,
          borderRadius: radius,
        ),
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: ColorConstants.black,
            size: 32,
          ),
        ),
      ),
    );
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

    return const SizedBox();
  }

  void _handleOnGuideNameChange(TrackAudioModel? value) {
    setState(() {
      var previousDuration = fileModel?.duration;
      selectedAudio = value;
      
      if (previousDuration != null && value != null) {
        fileModel = _findClosestDurationFile(value.files, previousDuration);
      } else {
        fileModel = value?.files.first;
      }
    });
  }

  TrackFilesModel _findClosestDurationFile(List<TrackFilesModel> files, int targetDuration) {
    return files.reduce((a, b) {
      return (a.duration - targetDuration).abs() < (b.duration - targetDuration).abs() ? a : b;
    });
  }

  void handleOnDurationChange(TrackFilesModel? value) {
    setState(() {
      fileModel = value;
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
          builder: (context) => const PlayerView(),
        ),
      ).then((value) => {
            ref.invalidate(packProvider),
          });
    } catch (e) {
      print(e);
    }
  }

  List<TrackFilesModel> files(List<TrackFilesModel> files) => files;

  Widget _durationDropdown(TrackModel trackModel, {required bool isLandscape}) {
    var audioFiles = trackModel.audio.first.files;
    var selectedFile = selectedAudio?.files;

    return DropdownWidget<TrackFilesModel>(
      value: fileModel ?? audioFiles.first,
      iconData: Icons.timer_sharp,
      topLeft: 7,
      topRight: 7,
      bottomRight: 7,
      bottomLeft: 7,
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
      isLandscape: isLandscape,
    );
  }

  Widget _guideNameDropdown(
    TrackModel trackModel, {
    required bool isLandscape,
  }) {
    var audio = trackModel.audio.first;
    if (audio.guideName.isNotNullAndNotEmpty()) {
      return DropdownWidget<TrackAudioModel>(
        value: selectedAudio ?? audio,
        iconData: Icons.face,
        bottomRight: 7,
        topLeft: 7,
        topRight: 7,
        bottomLeft: 7,
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
        isLandscape: isLandscape,
      );
    }

    return const SizedBox();
  }
}
