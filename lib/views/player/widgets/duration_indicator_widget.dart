import 'dart:math';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/duration_extensions.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class DurationIndicatorWidget extends ConsumerStatefulWidget {
  const DurationIndicatorWidget({
    super.key,
    required this.file,
    required this.meditationId,
  });
  final MeditationFilesModel file;
  final int meditationId;

  @override
  ConsumerState<DurationIndicatorWidget> createState() =>
      _DurationIndicatorWidgetState();
}

class _DurationIndicatorWidgetState
    extends ConsumerState<DurationIndicatorWidget> {
  final _minSeconds = 0.0;
  double? _dragSeekbarValue;
  late double _maxDuration;
  bool _draggingSeekbar = false;
  @override
  void initState() {
    _maxDuration = getMaxDuration(ref);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final audioPositionAndPlayerState =
        ref.watch(audioPositionAndPlayerStateProvider);

    return audioPositionAndPlayerState.when(
      data: (data) {
        final value = min(
          _dragSeekbarValue ?? data.position.inMilliseconds,
          _maxDuration,
        );
        if (_dragSeekbarValue != null && !_draggingSeekbar) {
          _dragSeekbarValue = null;
        }

        return _durationBar(
          context,
          ref,
          value,
          data.playerState.processingState,
        );
      },
      error: (error, stackTrace) => SizedBox(),
      loading: () => SizedBox(),
    );
  }

  Padding _durationBar(
    BuildContext context,
    WidgetRef ref,
    num currentDuration,
    ProcessingState audioProcessingState,
  ) {
    _handleAudioCompletion(
      ref,
      audioProcessingState,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              trackShape: CustomTrackShape(),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 5.0,
              ),
            ),
            child: Slider(
              min: _minSeconds,
              activeColor: ColorConstants.walterWhite,
              inactiveColor: ColorConstants.greyIsTheNewGrey,
              max: _maxDuration,
              value: currentDuration.toDouble(),
              onChanged: (val) {
                if (!_draggingSeekbar) {
                  _draggingSeekbar = true;
                }
                setState(() {
                  _dragSeekbarValue = val;
                });
                print('onChanged $val');
              },
              onChangeEnd: (val) {
                print('onChangeEnd ${val.round()}');
                print(
                  'Duration ${Duration(milliseconds: val.round()).toMinutesSeconds()}',
                );
                ref.read(slideAudioPositionProvider(
                  duration: val.round(),
                ));
                _draggingSeekbar = false;
              },
            ),
          ),
          // _durationLabel(
          //   context,
          //   audioProcessingState.name,
          // ),
          _durationLabels(
            context,
            currentDuration.round(),
            _maxDuration.round(),
          ),
        ],
      ),
    );
  }

  Row _durationLabels(
    BuildContext context,
    int position,
    int duration,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _durationLabel(
          context,
          Duration(milliseconds: position).toMinutesSeconds(),
        ),
        _durationLabel(
          context,
          Duration(milliseconds: duration).toMinutesSeconds(),
        ),
      ],
    );
  }

  Text _durationLabel(
    BuildContext context,
    String label,
  ) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ColorConstants.walterWhite,
            fontFamily: DmMono,
            fontSize: 14,
          ),
    );
  }

  void _handleAudioCompletion(
    WidgetRef ref,
    ProcessingState audioProcessingState,
  ) {
    if (audioProcessingState == ProcessingState.completed) {
      final audioProvider = ref.watch(audioPlayerNotifierProvider);
      _handleTrackEvent(ref, widget.file.id, widget.meditationId);
      audioProvider.stopMeditation();
      audioProvider.seekValueFromSlider(0);
      audioProvider.pauseBackgroundSound();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioPlayPauseStateProvider.notifier).state =
            PLAY_PAUSE_AUDIO.PAUSE;
      });
    }
  }

  void _handleTrackEvent(WidgetRef ref, int audioFileId, int meditationId) {
    var audio = AudioCompletedModel(
      audioFileId: audioFileId,
      meditationId: meditationId,
    );
    var event = EventsModel(
      name: EventTypes.audioCompleted,
      payload: audio.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  double getMaxDuration(
    WidgetRef ref,
  ) {
    var audioDuration =
        ref.read(audioPlayerNotifierProvider).getAudioDuration();

    return audioDuration != null
        ? audioDuration.inMilliseconds.toDouble()
        : widget.file.duration.toDouble();
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  CustomTrackShape({this.addTopPadding = true});

  final addTopPadding;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    var boxHeight = parentBox.size.height;
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    var trackTop;
    trackTop = addTopPadding
        ? offset.dy + (boxHeight - trackHeight) / 2 + 12
        : boxHeight / 2 - 2;
    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      additionalActiveTrackHeight: 0,
    );
  }
}
