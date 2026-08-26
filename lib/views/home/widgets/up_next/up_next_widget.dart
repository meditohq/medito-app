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
import '../home_gradient_border.dart';

const _kCardBorderRadius = 24.0;
const _kPlayButtonSize = 48.0;
const _kPlayButtonBorderWidth = 0.5;

/// Shared context for every Up Next event, so tap / skip / completion / pin all
/// carry the same dimensions and can be compared on a common denominator.
///
/// The important one is [AnalyticsEventConstants.paramUpNextMode]: it separates
/// the pre-change megapack cohort from users on the stepped sequence, which is
/// how we find out whether splitting the megapack changed listening behaviour
/// at all. Experience level is NOT included — it is a GA4 user property and so
/// is already attached to every event automatically.
Map<String, Object> _upNextEventParams(UpNextData data) {
  final packId = data.pack.id;
  final position = PackSequence.positionOf(packId);
  return {
    AnalyticsEventConstants.paramPackId: packId,
    AnalyticsEventConstants.paramUpNextMode: PackSequence.modeFor(packId),
    AnalyticsEventConstants.paramPackSequencePosition:
        position?.toString() ?? 'none',
    // completedCount + 1 is the session about to be played, 1-based.
    AnalyticsEventConstants.paramSessionIndexInPack: data.completedCount + 1,
    AnalyticsEventConstants.paramPackTotalSessions: data.totalCount,
  };
}

class UpNextWidget extends ConsumerWidget {
  /// Optional widget rendered inside the card below the main content (e.g. the
  /// explainer strip). When provided it collapses inside the card so the
  /// rounded corners are always intact.
  final Widget? inlineStrip;

  const UpNextWidget({super.key, this.inlineStrip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upNextAsync = ref.watch(upNextProvider);

    final child = upNextAsync.when(
      loading: () => const _UpNextShimmer(key: ValueKey('shimmer')),
      error: (_, _) => const SizedBox.shrink(key: ValueKey('error')),
      data: (upNextData) {
        // Finishing the pinned pack used to fall through to the shrink below,
        // so the card just vanished from home with no acknowledgement and no
        // way forward. Render the completion instead.
        if (upNextData.isCompleted) {
          return _UpNextCompleted(
            key: ValueKey('completed_${upNextData.pack.id}'),
            data: upNextData,
          );
        }

        if (upNextData.nextSession == null) {
          return const SizedBox.shrink(key: ValueKey('empty'));
        }

        return _UpNextContent(
          key: ValueKey(upNextData.nextSession!.id),
          data: upNextData,
          inlineStrip: inlineStrip,
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

/// Shown when every session in the pinned pack is complete.
///
/// Two variants: mid-path, where [UpNextData.nextPackId] holds the next pack in
/// [PackSequence] and the CTA pins it; and end-of-path, where there is nothing
/// left to offer. The end-of-path variant deliberately has no button — what it
/// should ultimately do is an open product decision, and
/// [AnalyticsEventConstants.upNextPathCompleted] is how we size that cohort
/// before designing for it. The Explore tab remains reachable from the nav bar
/// and any pack can still be pinned by hand from its pack view, so this is a
/// resting state rather than a dead end.
class _UpNextCompleted extends ConsumerStatefulWidget {
  final UpNextData data;

  const _UpNextCompleted({super.key, required this.data});

  @override
  ConsumerState<_UpNextCompleted> createState() => _UpNextCompletedState();
}

class _UpNextCompletedState extends ConsumerState<_UpNextCompleted> {
  bool _pinning = false;

  @override
  void initState() {
    super.initState();
    // Logged once per mount rather than per rebuild. The widget key includes the
    // pack id, so moving on to the next pack remounts and logs that pack's own
    // completion when it happens.
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
          // Same context as the rest: this fires for BOTH the last pack on the
          // path and the legacy megapack, and up_next_mode is what tells them
          // apart.
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
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.upNextNextPackPinned,
        parameters: {
          ..._upNextEventParams(widget.data),
          AnalyticsEventConstants.paramNextPackId: nextPackId,
          // Position the user is moving INTO, so path progression reads as a
          // sequence of hops rather than needing the id resolved downstream.
          AnalyticsEventConstants.paramNextPackSequencePosition:
              PackSequence.positionOf(nextPackId)?.toString() ?? 'none',
        },
      ),
    );

    // Same key and invalidation the pack view's manual pin uses, so both paths
    // stay consistent.
    await ref.read(sharedPreferencesProvider).setString(
      SharedPreferenceConstants.upNextPackId,
      nextPackId,
    );
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
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;
    final hasNext = widget.data.nextPackId != null;

    final title = hasNext
        ? l10n.upNextPackCompletedTitle(widget.data.pack.title)
        : l10n.upNextPathCompletedTitle;
    final subtitle = hasNext
        ? l10n.upNextPackCompletedSubtitle(widget.data.completedCount)
        : l10n.upNextPathCompletedSubtitle;

    // Name the pack the CTA will actually start. The title comes from the pack
    // API rather than a hardcoded list, so it stays localised and in sync with
    // the catalogue; until it resolves the generic label stands in, so the
    // button is never blank.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: Semantics(
        label: '$title. $subtitle',
        child: HomeGradientBorder(
          backgroundColor: theme.cardColor,
          borderRadius: _kCardBorderRadius,
          borderWidth: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(padding16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: context.brandPurple,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.upNextTitle.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: teachers,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: onSurface.withOpacityValue(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: sourceSerif,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurface.withOpacityValue(0.7),
                  ),
                ),
                if (hasNext) ...[
                  const SizedBox(height: padding16),
                  _CompletedCta(
                    label: ctaLabel,
                    busy: _pinning,
                    onTap: _onStartNextPack,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedCta extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _CompletedCta({
    required this.label,
    required this.busy,
    required this.onTap,
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
          backgroundColor: context.brandPurple,
          borderRadius: 12,
          borderWidth: _kPlayButtonBorderWidth,
          child: SizedBox(
            height: 48,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : ExcludeSemantics(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
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
  final Widget? inlineStrip;

  const _UpNextContent({super.key, required this.data, this.inlineStrip});

  @override
  ConsumerState<_UpNextContent> createState() => _UpNextContentState();
}

class _UpNextContentState extends ConsumerState<_UpNextContent> {
  bool _skipping = false;

  @override
  Widget build(BuildContext context) {
    final nextSession = widget.data.nextSession!;
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

    final borderRadius = BorderRadius.circular(_kCardBorderRadius);

    return AnimatedOpacity(
      opacity: _skipping ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding16),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Dismissible(
            key: Key('up_next_${nextSession.id}'),
            direction: DismissDirection.endToStart,
            background: _getSkipBackground(context, l10n),
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
                onTap: () => _onTap(context),
                child: HomeGradientBorder(
                  backgroundColor: cardColor,
                  borderRadius: _kCardBorderRadius,
                  borderWidth: 0.5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(padding16),
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
                                              fontFamily: teachers,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                              color: onSurface.withOpacityValue(
                                                0.7,
                                              ),
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '·',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontFamily: teachers,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: onSurface.withOpacityValue(
                                                0.7,
                                              ),
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.data.pack.title,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: teachers,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                                color: onSurface
                                                    .withOpacityValue(0.7),
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
                                          fontFamily: sourceSerif,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500,
                                          height: 1.2,
                                          color: onSurface,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: padding16),
                            _PlayButton(onTap: () => _onTap(context)),
                          ],
                        ),
                      ),
                      if (widget.inlineStrip != null) widget.inlineStrip!,
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

  Widget _getSkipBackground(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;

    return Container(
      color: theme.scaffoldBackgroundColor,
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
      try {
        await ref.read(playerProvider.notifier).play(request);
      } catch (e, st) {
        // play() now propagates native playback failures (see P0-4 in the
        // audit). Before this change, errors were swallowed and we'd
        // navigate to a silent player. Show a snackbar instead.
        AppLogger.e('UP_NEXT', 'Failed to start playback from Up Next', e, st);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.unableToLoadAudio),
          ),
        );
        return;
      }
      _navigateToPlayer(context);
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

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.play,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: HomeGradientBorder(
          backgroundColor: context.brandPurple,
          borderRadius: _kPlayButtonSize / 2,
          borderWidth: _kPlayButtonBorderWidth,
          child: const SizedBox(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
            child: ExcludeSemantics(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpNextShimmer extends StatelessWidget {
  const _UpNextShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: padding16,
      ),
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_kCardBorderRadius),
          border: Border.all(
            color: Color.lerp(cardColor, Colors.white, 0.3) ?? cardColor,
            width: 0.5,
          ),
        ),
      ),
    );
  }
}
