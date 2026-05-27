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
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
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
  final _analytics = FirebaseAnalyticsService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _logScreenView();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'TrackView',
      parameters: {'trackid': widget.trackId},
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final trackAsyncValue = ref.watch(tracksProvider(trackId: widget.trackId));
    final guideName = ref.watch(guideNamePreferenceProvider);
    final lastSelectedDuration = ref.watch(durationPreferenceProvider);

    void popContext() => Navigator.pop(context);

    final backButton = SingleBackButtonActionBar(onBackPressed: popContext);

    // Using 700 as a threshold for "cramped" vertical space where compact layout is preferred
    final useCompactLayout = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      bottomNavigationBar: trackAsyncValue.when(
        data: (track) => TrackViewBottomBar(
          trackId: widget.trackId,
          trackTitle: track.title,
          coverUrl: track.coverUrl,
          onBackPressed: popContext,
        ),
        loading: () => backButton,
        error: (_, _) => backButton,
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: trackAsyncValue.when(
                  data: (track) {
                    final selection = TrackVariantSelector.resolve(
                      track,
                      guideName: guideName,
                      durationMs: lastSelectedDuration,
                    );

                    return orientation == Orientation.portrait
                        ? _buildPortraitLayout(
                            track,
                            selection.voice,
                            selection.file,
                            useCompactLayout,
                          )
                        : _buildLandscapeLayout(
                            track,
                            selection.voice,
                            selection.file,
                          );
                  },
                  loading: () => const TrackShimmerWidget(),
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

  Widget _buildPortraitLayout(
    Track track,
    TrackVoice activeVoice,
    TrackAudioFile activeFile,
    bool useCompactLayout,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildCoverImage(track),
        ),
        const SizedBox(height: 24),
        _buildTrackContent(
          track,
          activeVoice,
          activeFile,
          isLandscape: false,
          useCompactLayout: useCompactLayout,
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(
    Track track,
    TrackVoice activeVoice,
    TrackAudioFile activeFile,
  ) {
    var size = MediaQuery.of(context).size;
    var maxWidth = size.width * 0.25;
    var maxHeight = size.height * 0.45;

    return Column(
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
                child: _buildCoverImage(track),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(context, track.title),
                      const SizedBox(height: 8),
                      _getSubTitle(
                        context,
                        track.description,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTrackContent(
          track,
          activeVoice,
          activeFile,
          isLandscape: true,
          useCompactLayout: false,
        ),
      ],
    );
  }

  Widget _buildCoverImage(Track track) {
    return _buildImageWithData(track.coverUrl);
  }

  Widget _buildImageWithData(String url) {
    return HomeGradientBorder(
      backgroundColor: Theme.of(context).cardColor,
      borderRadius: 20,
      borderWidth: 0.5,
      child: NetworkImageWidget(
        url: url,
        shouldCache: true,
      ),
    );
  }

  Widget _buildTrackContent(
    Track track,
    TrackVoice activeVoice,
    TrackAudioFile activeFile, {
    required bool isLandscape,
    required bool useCompactLayout,
  }) {
    final showGuideNameDropdown =
        track.voices.first.guideName.isNotNullAndNotEmpty();
    final guideName = ref.watch(guideNamePreferenceProvider);

    if (isLandscape) {
      return Row(children: [
        if (showGuideNameDropdown)
          Expanded(
              child: _guideNameDropdown(
            track,
            activeVoice,
            isLandscape: true,
            guideNameState: guideName,
          )),
        const SizedBox(width: 12),
        Expanded(
            child: _durationDropdown(activeVoice, activeFile,
                isLandscape: true)),
        const SizedBox(width: 12),
        Expanded(
            child: _playBtn(ref, track, activeVoice, activeFile,
                isFullWidth: false)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(context, track.title),
      const SizedBox(height: 8),
      _getSubTitle(context, track.description),
      const SizedBox(height: 24),
      if (useCompactLayout && showGuideNameDropdown)
        _buildCompactPickers(track, activeVoice, activeFile, guideName)
      else ...[
        if (showGuideNameDropdown) ...[
          _guideNameDropdown(
            track,
            activeVoice,
            isLandscape: false,
            guideNameState: guideName,
          ),
          const SizedBox(height: 12),
        ],
        _durationDropdown(activeVoice, activeFile, isLandscape: false),
      ],
      const SizedBox(height: 12),
      _playBtn(ref, track, activeVoice, activeFile, isFullWidth: true),
    ]);
  }

  Widget _buildCompactPickers(
    Track track,
    TrackVoice activeVoice,
    TrackAudioFile activeFile,
    String? guideNameState,
  ) {
    return Row(
      children: [
        Expanded(
          child: _guideNameDropdown(
            track,
            activeVoice,
            isLandscape: false,
            guideNameState: guideNameState,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _durationDropdown(activeVoice, activeFile, isLandscape: false),
        ),
      ],
    );
  }

  Widget _playBtn(
    WidgetRef ref,
    Track track,
    TrackVoice activeVoice,
    TrackAudioFile activeFile, {
    required bool isFullWidth,
  }) {
    // In dark mode a white fill pops against the ebony scaffold (~18:1).
    // In light mode the same white fill sits on #F8F9FA at ~1.07:1 and the
    // button disappears into the page — so switch to the themed primary
    // (WCAG-AA dark purple) with a white icon for light mode.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 56,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: () {
          _handlePlay(ref, track, activeVoice, activeFile);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? ColorConstants.white
              : Theme.of(context).colorScheme.primary,
          foregroundColor: isDark
              ? ColorConstants.black
              : Theme.of(context).colorScheme.onPrimary,
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: 32,
          semanticLabel: AppLocalizations.of(context)!.play,
        ),
      ),
    );
  }

  Text _title(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: sourceSerif,
            letterSpacing: 0.2,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.normal,
          ),
    );
  }

  Widget _getSubTitle(BuildContext context, String? subTitle) {
    if (subTitle != null) {
      return MarkdownWidget(
        body: subTitle,
        selectable: true,
        textAlign: WrapAlignment.start,
        p: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: dmSans,
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurface,
            ),
        a: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: dmSans,
              decoration: TextDecoration.underline,
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurface,
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

  void _handleOnGuideNameChange(TrackVoice? newVoice) {
    if (newVoice == null) return;

    ref
        .read(guideNamePreferenceProvider.notifier)
        .setGuideName(newVoice.guideName);

    // Keep the duration preference in step with what the new voice offers
    final currentDuration = ref.read(durationPreferenceProvider);
    if (currentDuration != null) {
      final bestFile = TrackVariantSelector.closestDuration(
        newVoice.audioFiles,
        currentDuration,
      );
      ref
          .read(durationPreferenceProvider.notifier)
          .setDuration(bestFile.duration);
    }
  }

  void _handleOnDurationChange(TrackAudioFile? value) {
    if (value != null) {
      ref.read(durationPreferenceProvider.notifier).setDuration(value.duration);
    }
  }

  void _handlePlay(
    WidgetRef ref,
    Track track,
    TrackVoice voice,
    TrackAudioFile file,
  ) async {
    try {
      final request = PlaybackRequest.fromTrack(track, voice, file);
      await ref.read(playerProvider.notifier).play(request);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerView(),
        ),
      );
    } catch (e, st) {
      AppLogger.e('TRACK', 'Failed to start playback', e, st);
      // Previously this swallowed the error AND navigated to PlayerView,
      // giving users a silent broken-looking player. Now play() rethrows
      // and navigation is skipped — show a snackbar so the failure is visible.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.unableToLoadAudio),
        ),
      );
    }
  }

  Widget _durationDropdown(
    TrackVoice activeVoice,
    TrackAudioFile activeFile, {
    required bool isLandscape,
  }) {
    return DropdownWidget<TrackAudioFile>(
      value: activeFile,
      iconData: Icons.timer_sharp,
      topLeft: 7,
      topRight: 7,
      bottomRight: 7,
      bottomLeft: 7,
      disabledLabelText:
          '${convertDurationToMinutes(milliseconds: activeFile.duration)} ${AppLocalizations.of(context)!.min}',
      items: activeVoice.audioFiles.map<DropdownMenuItem<TrackAudioFile>>(
        (TrackAudioFile value) {
          return DropdownMenuItem<TrackAudioFile>(
            value: value,
            child: Text(
              '${convertDurationToMinutes(milliseconds: value.duration)} ${AppLocalizations.of(context)!.min}',
            ),
          );
        },
      ).toList(),
      onChanged: _handleOnDurationChange,
      isLandscape: isLandscape,
    );
  }

  Widget _guideNameDropdown(
    Track track,
    TrackVoice activeVoice, {
    required bool isLandscape,
    required String? guideNameState,
  }) {
    if (activeVoice.guideName.isNotNullAndNotEmpty()) {
      return DropdownWidget<TrackVoice>(
        value: activeVoice,
        iconData: Icons.face,
        bottomRight: 7,
        topLeft: 7,
        topRight: 7,
        bottomLeft: 7,
        disabledLabelText: '${activeVoice.guideName}',
        items: track.voices.map<DropdownMenuItem<TrackVoice>>(
          (TrackVoice value) {
            return DropdownMenuItem<TrackVoice>(
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
