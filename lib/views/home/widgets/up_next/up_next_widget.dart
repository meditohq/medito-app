// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/models/models.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import '../home_gradient_border.dart';

const _kCardBorderRadius = 24.0;
const _kPlayButtonSize = 48.0;
const _kPlayButtonBorderWidth = 0.8;
const _kExplainerDarkBlue = Color(0xFF1A2744);

class UpNextWidget extends ConsumerWidget {
  const UpNextWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upNextAsync = ref.watch(upNextProvider);

    return upNextAsync.when(
      loading: () => const _UpNextShimmer(),
      error: (_, _) => const _UpNextShimmer(),
      data: (upNextData) {
        if (upNextData.nextSession == null) {
          return const SizedBox.shrink();
        }

        return _UpNextContent(data: upNextData);
      },
    );
  }
}

class _UpNextContent extends ConsumerStatefulWidget {
  final UpNextData data;

  const _UpNextContent({required this.data});

  @override
  ConsumerState<_UpNextContent> createState() => _UpNextContentState();
}

class _UpNextContentState extends ConsumerState<_UpNextContent>
    with TickerProviderStateMixin {
  bool _showExplainer = false;
  int _explainerStage = 1; // 1 = initial text + Got it, 2 = swipe hint
  late AnimationController _fadeController;
  late AnimationController _collapseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _collapseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );
    _checkExplainerVisibility();
  }

  void _checkExplainerVisibility() {
    final prefs = ref.read(sharedPreferencesProvider);
    final hasSeen =
        prefs.getBool(SharedPreferenceConstants.hasSeenYourPathExplainer) ??
            false;
    if (!hasSeen) {
      setState(() => _showExplainer = true);
      _fadeController.value = 1.0;
      _collapseController.value = 0.0;
      FirebaseAnalyticsService().logEvent(
        name: 'your_path_explainer_shown',
      );
    }
  }

  Future<void> _onGotItTap() async {
    // Fade out stage 1
    await _fadeController.reverse();
    setState(() => _explainerStage = 2);
    // Fade in stage 2
    await _fadeController.forward();
    // Wait 1.8 seconds
    await Future.delayed(const Duration(milliseconds: 1800));
    // Fade out stage 2
    await _fadeController.reverse();
    // Collapse the strip
    await _collapseController.forward();
    // Mark as seen
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(
        SharedPreferenceConstants.hasSeenYourPathExplainer, true);
    setState(() => _showExplainer = false);
    FirebaseAnalyticsService().logEvent(
      name: 'your_path_explainer_dismissed',
      parameters: {'method': 'got_it_tap'},
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextSession = widget.data.nextSession!;
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;
    final borderColor =
        Color.lerp(cardColor, Colors.white, 0.3) ?? cardColor;

    final cardBorderRadius = _showExplainer
        ? const BorderRadius.only(
            topLeft: Radius.circular(_kCardBorderRadius),
            topRight: Radius.circular(_kCardBorderRadius),
          )
        : BorderRadius.circular(_kCardBorderRadius);

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: padding16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: _showExplainer
                ? const BorderRadius.only(
                    topLeft: Radius.circular(_kCardBorderRadius),
                    topRight: Radius.circular(_kCardBorderRadius),
                  )
                : BorderRadius.circular(_kCardBorderRadius),
            child: Dismissible(
              key: Key('up_next_${nextSession.id}'),
              direction: DismissDirection.endToStart,
              background: _getSkipBackground(context, l10n),
              confirmDismiss: (_) async {
                await _onSkip(context);
                return false;
              },
              child: Semantics(
                label:
                    '${l10n.upNext}: ${widget.data.pack.title} – ${nextSession.title}',
                button: true,
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.skip): () =>
                      _onSkip(context),
                },
                child: GestureDetector(
                  onTap: () => _onTap(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: cardBorderRadius,
                      border: Border.all(
                        color: borderColor,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: cardBorderRadius,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'YOUR PATH',
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                fontFamily: teachers,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                                color:
                                                    ColorConstants.lightBlue,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '  ·  ',
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                fontFamily: teachers,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                                color:
                                                    ColorConstants.lightBlue,
                                              ),
                                            ),
                                            TextSpan(
                                              text: widget.data.pack.title,
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                fontFamily: teachers,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                                color:
                                                    ColorConstants.lightBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                                      if (nextSession.subtitle != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          nextSession.subtitle!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontFamily: teachers,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: onSurface.withValues(
                                                alpha: 0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: padding16),
                                _PlayButton(onTap: () => _onTap(context)),
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
          if (_showExplainer)
            _YourPathExplainerStrip(
              stage: _explainerStage,
              fadeAnimation: _fadeAnimation,
              collapseAnimation: _collapseAnimation,
              onGotIt: _onGotItTap,
              borderColor: borderColor,
            ),
        ],
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.skip_next_rounded, color: iconColor, size: 32),
                const SizedBox(height: 4),
                Text(
                  l10n.skip,
                  style: theme.textTheme.bodyMedium?.copyWith(
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

    final statsManager = StatsManager();
    await statsManager.initialize();
    await statsManager.addTrackChecked(nextSession.id);

    try {
      await ref.read(statsProvider.notifier).refreshFromLocal();
    } catch (_) {
      // Silently fail if refresh fails
    }

    ref.invalidate(upNextProvider);
  }

  Future<void> _onTap(BuildContext context) async {
    final nextSession = widget.data.nextSession;
    if (nextSession == null) return;

    final guideNameAsync = ref.read(guideNamePreferenceProvider);
    final preferredDuration = ref.read(durationPreferenceProvider);
    final guideName = guideNameAsync.hasValue ? guideNameAsync.value : null;

    if (guideName != null && preferredDuration != null) {
      await PermissionHandler.requestMediaPlaybackPermission(context);

      final trackId = nextSession.id;
      final cachedTrack = ref.read(playerProvider);

      TrackModel? trackState;

      if (cachedTrack?.id == trackId) {
        trackState = cachedTrack?.copyWith(title: nextSession.title);
      } else {
        trackState = await ref.read(tracksProvider(trackId: trackId).future);
      }

      final selectedAudio = _selectBestAudioMatch(
        trackState?.audio ?? [],
        guideName: guideName,
        preferredDuration: preferredDuration,
      );

      if (selectedAudio != null && trackState != null) {
        await ref
            .read(playerProvider.notifier)
            .loadSelectedTrack(
              trackModel: trackState,
              file: selectedAudio.files.first,
            );
        _navigateToPlayer(context);
      } else {
        handleNavigation(
          TypeConstants.track,
          [nextSession.id, nextSession.path],
          context,
          ref: ref,
        );
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
    ).then((value) => ref.invalidate(packProvider));
  }

  TrackAudioModel? _selectBestAudioMatch(
    List<TrackAudioModel> audioList, {
    String? guideName,
    int? preferredDuration,
  }) {
    if (audioList.isEmpty) return null;

    List<TrackAudioModel> filtered = guideName != null
        ? audioList.where((a) => a.guideName == guideName).toList()
        : audioList;

    if (filtered.isEmpty) filtered = audioList;

    TrackAudioModel? closest;
    int? closestDiff;

    for (final audio in filtered) {
      final duration = audio.files.first.duration;
      final diff = (preferredDuration ?? duration) - duration;

      if (closest == null || diff.abs() < closestDiff!) {
        closest = audio;
        closestDiff = diff.abs();
      }
    }

    return closest ?? audioList.first;
  }
}

class _YourPathExplainerStrip extends StatelessWidget {
  final int stage;
  final Animation<double> fadeAnimation;
  final Animation<double> collapseAnimation;
  final VoidCallback onGotIt;
  final Color borderColor;

  const _YourPathExplainerStrip({
    required this.stage,
    required this.fadeAnimation,
    required this.collapseAnimation,
    required this.onGotIt,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: collapseAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor:
              Tween<double>(begin: 1.0, end: 0.0).animate(collapseAnimation),
          axisAlignment: -1.0,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kExplainerDarkBlue,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(_kCardBorderRadius),
            bottomRight: Radius.circular(_kCardBorderRadius),
          ),
          border: Border(
            left: BorderSide(color: borderColor, width: 0.5),
            right: BorderSide(color: borderColor, width: 0.5),
            bottom: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
            padding16, padding12, padding16, padding16),
        child: FadeTransition(
          opacity: fadeAnimation,
          child: stage == 1
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.yourPathExplainerText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: teachers,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onGotIt,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.gotIt,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: teachers,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  l10n.yourPathSwipeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: teachers,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
        ),
      ),
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
          backgroundColor: ColorConstants.brightSky,
          borderRadius: _kPlayButtonSize / 2,
          borderWidth: _kPlayButtonBorderWidth,
          child: const SizedBox(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
            child: ExcludeSemantics(
              child: Icon(
                Icons.play_arrow_rounded,
                color: ColorConstants.ebony,
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
  const _UpNextShimmer();

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
