// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/providers/home/up_next_provider.dart';
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
import '../home_gradient_border.dart';

const _kCardBorderRadius = 24.0;
const _kPlayButtonSize = 48.0;
const _kPlayButtonBorderWidth = 0.8;

class UpNextWidget extends ConsumerWidget {
  const UpNextWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upNextAsync = ref.watch(upNextProvider);

    return upNextAsync.when(
      loading: () => const _UpNextShimmer(),
      error: (_, __) => const _UpNextShimmer(),
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

class _UpNextContentState extends ConsumerState<_UpNextContent> {
  @override
  Widget build(BuildContext context) {
    final nextSession = widget.data.nextSession!;
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: padding16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardBorderRadius),
        child: Dismissible(
          key: Key('up_next_${nextSession.id}'),
          direction: DismissDirection.endToStart,
          background: _getSkipBackground(context, l10n),
          confirmDismiss: (_) async {
            await _onSkip(context);
            return false;
          },
            child: GestureDetector(
            onTap: () => _onTap(context),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(_kCardBorderRadius),
                border: Border.all(
                  color: Color.lerp(cardColor, Colors.white, 0.3) ?? cardColor,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kCardBorderRadius),
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
                                    'UP NEXT',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: teachers,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.data.pack.title,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: teachers,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nextSession.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: teachers,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: onSurface.withValues(alpha: 0.6),
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

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: HomeGradientBorder(
        backgroundColor: ColorConstants.brightSky,
        borderRadius: _kPlayButtonSize / 2,
        borderWidth: _kPlayButtonBorderWidth,
        child: SizedBox(
          width: _kPlayButtonSize,
          height: _kPlayButtonSize,
          child: const Icon(
            Icons.play_arrow_rounded,
            color: ColorConstants.ebony,
            size: 28,
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
