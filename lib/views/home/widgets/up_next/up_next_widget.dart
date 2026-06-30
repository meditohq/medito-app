// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
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
import 'dart:async';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/providers/providers.dart';
import '../home_gradient_border.dart';

const _kCardBorderRadius = 24.0;
const _kPlayButtonSize = 48.0;
const _kPlayButtonBorderWidth = 0.5;

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
              AnalyticsEventConstants.paramPackId: widget.data.pack.id,
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
              AnalyticsEventConstants.paramPackId: widget.data.pack.id,
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
