// ignore_for_file: use_build_context_synchronously
import '../../../utils/logger.dart';

import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/player/widgets/bottom_actions/track_view_bottom_bar.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackView extends ConsumerStatefulWidget {
  const TrackView({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView>
    with AutomaticKeepAliveClientMixin<TrackView> {
  final ScrollController _scrollController = ScrollController();
  TrackAudioModel? selectedAudio;
  TrackFilesModel? fileModel;
  final GlobalKey _contentKey = GlobalKey();
  bool _useCompactLayout = false;
  final _analytics = FirebaseAnalyticsService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
      _logScreenView();
    });
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'TrackView');
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollListener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final trackAsyncValue = ref.watch(tracksProvider(trackId: widget.trackId));
    final guideNameState = ref.watch(guideNamePreferenceProvider);
    final lastSelectedDuration = ref.watch(durationPreferenceProvider);

    void popContext() => Navigator.pop(context);

    // Create a reusable back button widget
    final backButton = SingleBackButtonActionBar(onBackPressed: popContext);

    // Initialize selected audio and file model when track data changes
    trackAsyncValue.whenData((trackModel) {
      if (trackModel.audio.isNotEmpty &&
          selectedAudio == null &&
          guideNameState is AsyncData<String?>) {
        var initialAudio = guideNameState.value != null
            ? trackModel.audio.firstWhere(
                (audio) => audio.guideName == guideNameState.value,
                orElse: () => trackModel.audio.first,
              )
            : trackModel.audio.first;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            selectedAudio = initialAudio;
            fileModel = lastSelectedDuration != null
                ? _findClosestDurationFile(
                    initialAudio.files, lastSelectedDuration)
                : initialAudio.files.first;
          });
        });
      }
    });

    return Scaffold(
      bottomNavigationBar: trackAsyncValue.when(
        data: (track) => TrackViewBottomBar(
          trackId: widget.trackId,
          trackTitle: track.title,
          coverUrl: track.coverUrl,
          onBackPressed: popContext,
        ),
        loading: () => backButton,
        error: (_, __) => backButton,
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
                  error: (err, stack) {
                    final error = err is AppError ? err : const UnknownError();
                    return MeditoErrorWidget(
                      error: error,
                      onTap: () =>
                          ref.refresh(tracksProvider(trackId: widget.trackId)),
                      isScaffold: false,
                    );
                  },
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
                error: (err, stack) {
                  final error = err is AppError ? err : const UnknownError();
                  return MeditoErrorWidget(
                    error: error,
                    onTap: () =>
                        ref.refresh(tracksProvider(trackId: widget.trackId)),
                    isScaffold: false,
                  );
                },
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
      child: Container(color: ColorConstants.black.withOpacity(0.6)),
    );
  }

  Widget _buildErrorCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(color: ColorConstants.black.withOpacity(0.6)),
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
      error: (err, stack) {
        final error = err is AppError ? err : const UnknownError();
        return MeditoErrorWidget(
          error: error,
          onTap: () => ref.refresh(tracksProvider(trackId: widget.trackId)),
          isScaffold: false,
        );
      },
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
              Expanded(
                  child: _guideNameDropdown(trackModel,
                      isLandscape: true,
                      guideNameState: ref.watch(guideNamePreferenceProvider))),
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
              _buildCompactPickers(trackModel, ref)
            else ...[
              if (showGuideNameDropdown) ...[
                _guideNameDropdown(trackModel,
                    isLandscape: false,
                    guideNameState: ref.watch(guideNamePreferenceProvider)),
                const SizedBox(height: 12),
              ],
              _durationDropdown(trackModel, isLandscape: false),
            ],
            const SizedBox(height: 12),
            _playBtn(ref, trackModel, isFullWidth: true),
          ]);
  }

  Widget _buildCompactPickers(TrackModel trackModel, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _guideNameDropdown(trackModel,
              isLandscape: false,
              guideNameState: ref.watch(guideNamePreferenceProvider)),
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
          color: ColorConstants.white,
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
            fontFamily: sourceSerif,
            color: ColorConstants.white,
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
          color: ColorConstants.white,
          fontFamily: dmSans,
          fontSize: 16,
        ),
        a: bodyLarge?.copyWith(
          color: ColorConstants.white,
          fontFamily: dmSans,
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

  void _handleOnGuideNameChange(TrackAudioModel? selectedAudio) {
    setState(() {
      var previousDuration = fileModel?.duration;

      if (previousDuration != null && selectedAudio != null) {
        fileModel =
            _findClosestDurationFile(selectedAudio.files, previousDuration);
      } else {
        fileModel = selectedAudio?.files.first;
      }
      this.selectedAudio = selectedAudio;
      ref
          .read(guideNamePreferenceProvider.notifier)
          .setGuideName(selectedAudio?.guideName);
      ref
          .read(durationPreferenceProvider.notifier)
          .setDuration(fileModel?.duration);
    });
  }

  TrackFilesModel _findClosestDurationFile(
    List<TrackFilesModel> files,
    int targetDuration,
  ) {
    return files.reduce((a, b) {
      final aDiff = (a.duration - targetDuration).abs();
      final bDiff = (b.duration - targetDuration).abs();
      return aDiff < bDiff ? a : b;
    });
  }

  void handleOnDurationChange(TrackFilesModel? value) {
    setState(() {
      fileModel = value;
    });
    if (value != null) {
      ref.read(durationPreferenceProvider.notifier).setDuration(value.duration);
    }
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
      AppLogger.d('TRACK', e.toString());
    }
  }

  List<TrackFilesModel> files(List<TrackFilesModel> files) => files;

  Widget _durationDropdown(TrackModel trackModel, {required bool isLandscape}) {
    var audioFiles = trackModel.audio.first.files;
    var selectedFile = selectedAudio?.files ?? audioFiles;

    return DropdownWidget<TrackFilesModel>(
      value: fileModel ?? audioFiles.first,
      iconData: Icons.timer_sharp,
      topLeft: 7,
      topRight: 7,
      bottomRight: 7,
      bottomLeft: 7,
      disabledLabelText:
          '${convertDurationToMinutes(milliseconds: selectedFile.first.duration)} ${AppLocalizations.of(context)!.min}',
      items: files(selectedFile).map<DropdownMenuItem<TrackFilesModel>>(
        (TrackFilesModel value) {
          return DropdownMenuItem<TrackFilesModel>(
            value: value,
            child: Text(
              '${convertDurationToMinutes(milliseconds: value.duration)} ${AppLocalizations.of(context)!.min}',
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
    required AsyncValue<String?> guideNameState,
  }) {
    var audio = trackModel.audio.first;
    if (audio.guideName.isNotNullAndNotEmpty()) {
      if (guideNameState.isLoading) {
        return const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        );
      }
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
