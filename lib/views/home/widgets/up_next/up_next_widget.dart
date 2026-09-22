// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/pack_sequence.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/models/models.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'dart:async';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/providers/providers.dart';
import '../../home_styles.dart';
import '../home_gradient_border.dart';

const _kCardBorderRadius = kHomeHeroRadius;
const _kPlayButtonSize = 52.0;
const _kProgressBarHeight = 3.0;

/// Shared context for every Up Next event so the four are comparable.
/// Experience level is omitted — it is a user property, already on every event.
Map<String, Object> _upNextEventParams(UpNextData data) {
  final packId = data.pack.id;
  final position = PackSequence.positionOf(packId);
  return {
    AnalyticsEventConstants.paramPackId: packId,
    AnalyticsEventConstants.paramUpNextMode: PackSequence.modeFor(packId),
    AnalyticsEventConstants.paramPackSequencePosition:
        position?.toString() ?? 'none',
    AnalyticsEventConstants.paramSessionIndexInPack: data.completedCount + 1,
    AnalyticsEventConstants.paramPackTotalSessions: data.totalCount,
  };
}

/// How the Up Next content is presented.
enum UpNextStyle {
  /// Its own card in the home list.
  card,

  /// Laid over the home hero image: no surface, white text, white play button.
  hero,
}

/// Colours for the Up Next content in either [UpNextStyle].
class _UpNextPalette {
  const _UpNextPalette({
    required this.foreground,
    required this.muted,
    required this.track,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.skipBackground,
  });

  factory _UpNextPalette.of(BuildContext context, UpNextStyle style) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (style == UpNextStyle.hero) {
      // The hero's lower half fades toward the page colour: near-black in
      // dark mode, white in light mode. Text goes the opposite way and the
      // play button is the theme's inverted accent.
      final fg = isDark ? Colors.white : const Color(0xFF0A0A0A);
      return _UpNextPalette(
        foreground: fg,
        muted: fg.withValues(alpha: 0.78),
        track: fg.withValues(alpha: isDark ? 0.25 : 0.15),
        buttonBackground: isDark ? Colors.white : const Color(0xFF171717),
        buttonForeground: isDark ? const Color(0xFF171717) : Colors.white,
        skipBackground: (isDark ? Colors.black : Colors.white).withValues(
          alpha: 0.35,
        ),
      );
    }
    final onSurface = theme.colorScheme.onSurface;
    return _UpNextPalette(
      foreground: onSurface,
      muted: onSurface.withOpacityValue(0.7),
      track: onSurface.withOpacityValue(0.1),
      buttonBackground: context.brandPurple,
      buttonForeground: context.onBrandPurple,
      skipBackground: theme.scaffoldBackgroundColor,
    );
  }

  final Color foreground;
  final Color muted;
  final Color track;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color skipBackground;
}

class UpNextWidget extends ConsumerWidget {
  final UpNextStyle style;

  const UpNextWidget({super.key, this.style = UpNextStyle.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upNextAsync = ref.watch(upNextProvider);

    final child = upNextAsync.when(
      loading: () =>
          _UpNextShimmer(key: const ValueKey('shimmer'), style: style),
      error: (_, _) => const SizedBox.shrink(key: ValueKey('error')),
      data: (upNextData) {
        if (upNextData.isCompleted) {
          return _UpNextCompleted(
            key: ValueKey('completed_${upNextData.pack.id}'),
            data: upNextData,
            style: style,
          );
        }

        if (upNextData.nextSession == null) {
          return const SizedBox.shrink(key: ValueKey('empty'));
        }

        return _UpNextContent(
          key: ValueKey(upNextData.nextSession!.id),
          data: upNextData,
          style: style,
        );
      },
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// Shown when the pinned pack is fully complete. Mid-path the CTA pins the next
/// pack; at the end of the path there is no CTA (still an open decision).
class _UpNextCompleted extends ConsumerStatefulWidget {
  final UpNextData data;
  final UpNextStyle style;

  const _UpNextCompleted({
    super.key,
    required this.data,
    this.style = UpNextStyle.card,
  });

  @override
  ConsumerState<_UpNextCompleted> createState() => _UpNextCompletedState();
}

class _UpNextCompletedState extends ConsumerState<_UpNextCompleted> {
  bool _pinning = false;

  @override
  void initState() {
    super.initState();
    // Once per mount, not per rebuild; the key is keyed on the pack id.
    WidgetsBinding.instance.addPostFrameCallback((_) => _logShown());
  }

  void _logShown() {
    final analytics = ref.read(analyticsServiceProvider);

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.upNextPackCompleted,
        parameters: {
          ..._upNextEventParams(widget.data),
          AnalyticsEventConstants.paramHasNextPack:
              widget.data.nextPackId != null ? 'true' : 'false',
        },
      ),
    );

    if (widget.data.isEndOfPath) {
      unawaited(
        analytics.logEvent(
          name: AnalyticsEventConstants.upNextPathCompleted,
          parameters: _upNextEventParams(widget.data),
        ),
      );
    }
  }

  Future<void> _onStartNextPack() async {
    final nextPackId = widget.data.nextPackId;
    if (nextPackId == null || _pinning) return;

    setState(() => _pinning = true);

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.upNextNextPackPinned,
            parameters: {
              ..._upNextEventParams(widget.data),
              AnalyticsEventConstants.paramNextPackId: nextPackId,
              AnalyticsEventConstants.paramNextPackSequencePosition:
                  PackSequence.positionOf(nextPackId)?.toString() ?? 'none',
            },
          ),
    );

    // Same key and invalidation as the pack view's manual pin.
    await ref
        .read(sharedPreferencesProvider)
        .setString(SharedPreferenceConstants.upNextPackId, nextPackId);
    ref.invalidate(upNextPackIdProvider);

    if (!mounted) return;
    setState(() => _pinning = false);
    showSnackBar(
      context,
      AppLocalizations.of(context)!.upNextNextPackPinnedSnack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _UpNextPalette.of(context, widget.style);
    final onSurface = palette.foreground;
    final isHero = widget.style == UpNextStyle.hero;
    final l10n = AppLocalizations.of(context)!;
    final hasNext = widget.data.nextPackId != null;

    final title = hasNext
        ? l10n.upNextPackCompletedTitle(widget.data.pack.title)
        : l10n.upNextPathCompletedTitle;
    final subtitle = hasNext
        ? l10n.upNextPackCompletedSubtitle(widget.data.completedCount)
        : l10n.upNextPathCompletedSubtitle;

    // Title from the API, not a hardcoded list; generic label while it loads.
    var ctaLabel = l10n.upNextPackCompletedCta;
    if (hasNext) {
      final nextTitle = ref
          .watch(packProvider(packId: widget.data.nextPackId!))
          .value
          ?.title;
      if (nextTitle != null && nextTitle.isNotEmpty) {
        ctaLabel = l10n.upNextPackCompletedCtaNamed(nextTitle);
      }
    }

    final body = Padding(
      padding: isHero
          ? EdgeInsets.fromLTRB(
              padding16,
              padding16,
              MediaQuery.sizeOf(context).width >= 600 ? 32 : padding16,
              padding16,
            )
          : const EdgeInsets.all(padding20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: isHero ? palette.foreground : context.brandPurple,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.upNextTitle.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: isHero ? 28 : 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          if (hasNext) ...[
            const SizedBox(height: padding16),
            _CompletedCta(
              label: ctaLabel,
              busy: _pinning,
              onTap: _onStartNextPack,
              palette: palette,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      label: '$title. $subtitle',
      child: isHero
          ? body
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: padding16),
              child: HomeGradientBorder(
                backgroundColor: theme.cardColor,
                borderRadius: _kCardBorderRadius,
                borderWidth: 0.5,
                child: body,
              ),
            ),
    );
  }
}

class _CompletedCta extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;
  final _UpNextPalette palette;

  const _CompletedCta({
    required this.label,
    required this.busy,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: !busy,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: HomeGradientBorder(
          backgroundColor: palette.buttonBackground,
          borderRadius: 14,
          borderWidth: 0.5,
          child: SizedBox(
            height: 48,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.buttonForeground,
                      ),
                    )
                  : ExcludeSemantics(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: palette.buttonForeground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpNextContent extends ConsumerStatefulWidget {
  final UpNextData data;
  final UpNextStyle style;

  const _UpNextContent({
    super.key,
    required this.data,
    this.style = UpNextStyle.card,
  });

  @override
  ConsumerState<_UpNextContent> createState() => _UpNextContentState();
}

class _UpNextContentState extends ConsumerState<_UpNextContent> {
  bool _skipping = false;
  // True while the track is being fetched and the player is opening. Shows a
  // spinner in the play button and blocks a duplicate tap.
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final nextSession = widget.data.nextSession!;
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final palette = _UpNextPalette.of(context, widget.style);
    final isHero = widget.style == UpNextStyle.hero;
    final l10n = AppLocalizations.of(context)!;

    final borderRadius = BorderRadius.circular(_kCardBorderRadius);

    return AnimatedOpacity(
      opacity: _skipping ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isHero ? 0 : padding16),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Dismissible(
            key: Key('up_next_${nextSession.id}'),
            direction: DismissDirection.endToStart,
            background: _getSkipBackground(context, l10n, palette),
            movementDuration: const Duration(milliseconds: 1),
            confirmDismiss: (_) async {
              await _onSkip(context);
              return false;
            },
            child: Semantics(
              label:
                  '${l10n.upNext}: ${widget.data.pack.title} — ${nextSession.title}',
              button: true,
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.skip): () => _onSkip(context),
              },
              child: GestureDetector(
                // The hero style has no card surface behind the content, so
                // without this only the painted text and the play circle
                // would take taps; the space beside the title fell through
                // to the image (smoke run 34957204808 tapped the card centre
                // and nothing happened).
                behavior: HitTestBehavior.opaque,
                onTap: () => _onTap(context),
                child: _Surface(
                  style: widget.style,
                  color: cardColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: isHero
                            ? EdgeInsets.fromLTRB(
                                padding16,
                                padding16,
                                MediaQuery.sizeOf(context).width >= 600
                                    ? 32
                                    : padding16,
                                padding16,
                              )
                            : const EdgeInsets.all(padding20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        l10n.upNextTitle.toUpperCase(),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                              color: palette.muted,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '·',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: palette.muted,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.data.pack.title,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                                color: palette.muted,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    nextSession.title,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontSize: isHero ? 28 : 22,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                          color: palette.foreground,
                                        ),
                                  ),
                                  if (widget.data.totalCount > 0) ...[
                                    const SizedBox(height: 10),
                                    _ProgressRow(
                                      completed: widget.data.completedCount,
                                      total: widget.data.totalCount,
                                      palette: palette,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: padding16),
                            _PlayButton(
                              onTap: () => _onTap(context),
                              palette: palette,
                              isLoading: _isStarting,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getSkipBackground(
    BuildContext context,
    AppLocalizations l10n,
    _UpNextPalette palette,
  ) {
    final theme = Theme.of(context);
    final iconColor = palette.foreground;

    return Container(
      color: palette.skipBackground,
      child: Padding(
        padding: const EdgeInsets.all(padding16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.skip_next_rounded, color: iconColor, size: 28),
                const SizedBox(height: 4),
                Text(
                  l10n.skip,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSkip(BuildContext context) async {
    final nextSession = widget.data.nextSession;
    if (nextSession == null) return;

    setState(() => _skipping = true);

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.upNextSkipped,
            parameters: {
              AnalyticsEventConstants.paramSessionId: nextSession.id,
              ..._upNextEventParams(widget.data),
            },
          ),
    );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFirstActionAfterOnboardingIfNeeded('up_next_skip'),
    );

    final statsManager = ref.read(statsManagerProvider);
    await statsManager.initialize();
    await statsManager.addTrackChecked(nextSession.id);

    try {
      await ref.read(statsProvider.notifier).refreshFromLocal();
    } catch (_) {
      // Silently fail if refresh fails
    }
    // upNextProvider rebuilds reactively via packProvider <- statsProvider.
  }

  Future<void> _onTap(BuildContext context) async {
    final nextSession = widget.data.nextSession;
    if (nextSession == null) return;
    if (_isStarting) return;

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.upNextTapped,
            parameters: {
              AnalyticsEventConstants.paramSessionId: nextSession.id,
              ..._upNextEventParams(widget.data),
            },
          ),
    );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFirstActionAfterOnboardingIfNeeded('up_next'),
    );

    final guideName = ref.read(guideNamePreferenceProvider);
    final preferredDuration = ref.read(durationPreferenceProvider);

    if (guideName != null && preferredDuration != null) {
      setState(() => _isStarting = true);
      try {
        final track = await ref.read(
          tracksProvider(trackId: nextSession.id).future,
        );
        final selection = TrackVariantSelector.resolve(
          track,
          guideName: guideName,
          durationMs: preferredDuration,
        );

        final request = PlaybackRequest.fromTrack(
          track,
          selection.voice,
          selection.file,
        );
        if (!context.mounted) return;
        // Prepare + open the player immediately; PlayerView starts playback
        // and shows its own loading state. The button spinner covers only the
        // track fetch above.
        ref.read(playerProvider.notifier).prepare(request);
        _navigateToPlayer(context);
      } catch (e, st) {
        // The track fetch failed (offline / bad response) so we never reached
        // the player — surface it here rather than leaving a dead tap.
        AppLogger.e('UP_NEXT', 'Failed to start playback from Up Next', e, st);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.unableToLoadAudio),
          ),
        );
      } finally {
        if (mounted) setState(() => _isStarting = false);
      }
    } else {
      handleNavigation(
        TypeConstants.track,
        [nextSession.id, nextSession.path],
        context,
        ref: ref,
      );
    }
  }

  void _navigateToPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayerView()),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  final _UpNextPalette palette;
  final bool isLoading;

  const _PlayButton({
    required this.onTap,
    required this.palette,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: isLoading ? l10n.loading : l10n.play,
      button: !isLoading,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.buttonBackground,
          ),
          child: SizedBox(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
            child: ExcludeSemantics(
              // Same box size whether icon or spinner, so nothing shifts.
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.buttonForeground,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.play_arrow_rounded,
                      color: palette.buttonForeground,
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card surface in [UpNextStyle.card]; nothing at all in [UpNextStyle.hero],
/// where the hero image and its scrim are the surface.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.style,
    required this.color,
    required this.child,
  });

  final UpNextStyle style;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (style == UpNextStyle.hero) return child;
    return HomeGradientBorder(
      backgroundColor: color,
      borderRadius: _kCardBorderRadius,
      borderWidth: 0.5,
      child: child,
    );
  }
}

/// Thin pack progress bar with a "3 of 7" caption in the eyebrow's voice.
class _ProgressRow extends StatelessWidget {
  final int completed;
  final int total;
  final _UpNextPalette palette;

  const _ProgressRow({
    required this.completed,
    required this.total,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kProgressBarHeight / 2),
            child: LinearProgressIndicator(
              value: (completed / total).clamp(0.0, 1.0),
              minHeight: _kProgressBarHeight,
              backgroundColor: palette.track,
              color: palette.buttonBackground,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppLocalizations.of(context)!.upNextProgress(completed, total),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: palette.muted,
          ),
        ),
      ],
    );
  }
}

class _UpNextShimmer extends StatelessWidget {
  const _UpNextShimmer({super.key, this.style = UpNextStyle.card});

  final UpNextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    // Over the hero the image is the loading state.
    if (style == UpNextStyle.hero) return const SizedBox(height: 96);

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: padding16,
      ),
      child: HomeGradientBorder(
        backgroundColor: cardColor,
        borderRadius: _kCardBorderRadius,
        borderWidth: 0.5,
        child: const SizedBox(height: 128, width: double.infinity),
      ),
    );
  }
}
