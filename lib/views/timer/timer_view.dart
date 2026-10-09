import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/timer/timer_settings_provider.dart';
import 'package:medito/repositories/background_sounds/background_sounds_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/audio/timer_audio_file.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/widgets/network_image_widget.dart';
import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/widgets/inputs/medito_segmented_tabs.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';

import 'widgets/timer_duration_wheels.dart';

/// The home Timer: pick a length (or an open-ended stopwatch) and a sound,
/// then sit with the regular player. Works fully offline — the session is a
/// locally generated silent track, so nothing is fetched.
class TimerView extends ConsumerStatefulWidget {
  const TimerView({super.key, required this.source});

  /// Where the screen was opened from, for timer_opened (see
  /// [AnalyticsEventConstants.timerOpened]).
  final String source;

  @override
  ConsumerState<TimerView> createState() => _TimerViewState();
}

class _TimerViewState extends ConsumerState<TimerView> {
  final _wheels = GlobalKey<TimerDurationWheelsState>();
  bool _starting = false;

  /// How the countdown length was set, for timer_started: remembered or
  /// default until the user touches a chip (preset) or the wheels (wheel).
  late String _lengthSource;

  /// Cover of the old timer track, shown in the player when it could be
  /// fetched. Never awaited: offline the player falls back to its dark
  /// backdrop and the timer starts just the same.
  String? _coverUrl;

  BackgroundSoundsRepository get _soundRepo =>
      ref.read(backgroundSoundsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    // Last known cover first: its image is in the disk cache, so the
    // backdrop shows offline too. The fetch below refreshes it.
    _coverUrl = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.timerCoverUrl);
    unawaited(_loadCover());
    _lengthSource =
        ref
                .read(sharedPreferencesProvider)
                .getInt(SharedPreferenceConstants.timerMinutes) ==
            null
        ? 'default'
        : 'remembered';
    final analytics = FirebaseAnalyticsService();
    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.timerOpened,
        parameters: {AnalyticsEventConstants.paramSource: widget.source},
      ),
    );
    unawaited(analytics.logScreenView(screenName: 'TimerView'));
  }

  Future<void> _loadCover() async {
    try {
      final track = await ref
          .read(trackRepositoryProvider)
          .fetchTrack(kLegacyTimerTrackId);
      final url = track.coverUrl;
      if (!mounted || url.isEmpty || HTTPConstants.isDeadDomain(url)) return;
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setString(SharedPreferenceConstants.timerCoverUrl, url),
      );
      if (url != _coverUrl) setState(() => _coverUrl = url);
      // Warm the image so the player opens with it instead of fading it in.
      unawaited(precacheImage(NetworkImage(url), context, onError: (_, _) {}));
    } catch (e) {
      AppLogger.d('TIMER', 'Timer cover unavailable: $e');
    }
  }

  Future<void> _start() async {
    final settings = ref.read(timerSettingsProvider);
    if (_starting || !settings.canStart) return;
    setState(() => _starting = true);
    final l10n = AppLocalizations.of(context)!;
    unawaited(HapticFeedback.mediumImpact());

    try {
      final duration = settings.sessionDuration;
      final path = await TimerAudioFile.prepare(duration);
      final request = timerPlaybackRequest(
        mode: settings.mode,
        duration: duration,
        filePath: path,
        title: settings.mode == TimerMode.stopwatch
            ? l10n.timerModeStopwatch
            : l10n.timerTitle,
        coverUrl: _coverUrl,
      );
      unawaited(
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.timerStarted,
          parameters: {
            AnalyticsEventConstants.paramTimerMode: settings.mode.name,
            AnalyticsEventConstants.paramDurationMinutes:
                settings.mode == TimerMode.stopwatch ? 0 : settings.minutes,
            if (settings.mode == TimerMode.countdown)
              AnalyticsEventConstants.paramLengthSource: _lengthSource,
            // Ambient sound and bells, as last left in the player.
            AnalyticsEventConstants.paramSoundId:
                _soundRepo.getSelectedBgSoundFromSharedPreferences()?.id ??
                kNoneBackgroundSoundId,
            AnalyticsEventConstants.paramSessionBells:
                _soundRepo.getSessionBellsEnabled(forTimer: true) ? 1 : 0,
          },
        ),
      );
      if (!mounted) return;
      ref.read(playerProvider.notifier).prepare(request);
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerView()),
        ),
      );
    } catch (e, st) {
      AppLogger.e('TIMER', 'Failed to start timer', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.unableToLoadAudio)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _selectPreset(int minutes) {
    unawaited(HapticFeedback.selectionClick());
    _lengthSource = 'preset';
    ref.read(timerSettingsProvider.notifier).setMinutes(minutes);
    _wheels.currentState?.animateTo(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(timerSettingsProvider);
    final isStopwatch = settings.mode == TimerMode.stopwatch;

    final coverUrl = _coverUrl;

    // Laid out like the track screen: cover card, title, then the controls.
    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: AdaptivePageBody(
        maxWidth: 600,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (coverUrl != null) ...[
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: HomeGradientBorder(
                            backgroundColor: Theme.of(context).cardColor,
                            borderRadius: 20,
                            borderWidth: 0.5,
                            child: NetworkImageWidget(
                              url: coverUrl,
                              shouldCache: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      MeditoSegmentedTabs(
                        labels: [l10n.timerTitle, l10n.timerModeStopwatch],
                        selectedIndex: settings.mode.index,
                        onChanged: (index) {
                          unawaited(HapticFeedback.selectionClick());
                          ref
                              .read(timerSettingsProvider.notifier)
                              .setMode(TimerMode.values[index]);
                        },
                      ),
                      const SizedBox(height: 16),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isStopwatch) const _StopwatchInfo(),
                            // Kept mounted while hidden so switching back
                            // keeps the wheels' position.
                            Visibility(
                              visible: !isStopwatch,
                              maintainState: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TimerDurationWheels(
                                    key: _wheels,
                                    minutes: settings.minutes,
                                    // Only user drags report here; a
                                    // preset's spin is suppressed.
                                    onChanged: (minutes) {
                                      _lengthSource = 'wheel';
                                      ref
                                          .read(timerSettingsProvider.notifier)
                                          .setMinutes(minutes);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _PresetChips(
                                    selectedMinutes: settings.minutes,
                                    onSelected: _selectPreset,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _StartButton(
                  enabled: settings.canStart,
                  loading: _starting,
                  onPressed: _start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopwatchInfo extends StatelessWidget {
  const _StopwatchInfo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurface = theme.colorScheme.onSurface;
    return HomeGradientBorder(
      backgroundColor: theme.cardColor,
      borderRadius: 16,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.all_inclusive_rounded, color: onSurface, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Same type as the sound rows in the player's sheet.
                  Text(
                    l10n.timerStopwatchTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.timerStopwatchCaption,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChips extends StatelessWidget {
  const _PresetChips({required this.selectedMinutes, required this.onSelected});

  static const height = 58.0;

  final int selectedMinutes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final minutes in kTimerPresetMinutes)
            _PresetChip(
              minutes: minutes,
              selected: minutes == selectedMinutes,
              label: l10n.min,
              semanticLabel: l10n.timerPresetSemantics(minutes),
              onTap: () => onSelected(minutes),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.minutes,
    required this.selected,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    required this.theme,
  });

  final int minutes;
  final bool selected;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final background = selected ? context.brandAccent : theme.cardColor;
    final foreground = selected
        ? context.onBrandAccent
        : theme.colorScheme.onSurface;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      excludeSemantics: true,
      // excludeSemantics also drops the InkWell's tap action below, so the
      // chip was announced as a button that did nothing.
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _PresetChips.height,
        height: _PresetChips.height,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$minutes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.7),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Same as the track screen's Play: the themed primary button at 56pt.
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled && !loading ? onPressed : null,
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.onBrandAccent,
                ),
              )
            : Text(AppLocalizations.of(context)!.timerStart),
      ),
    );
  }
}
