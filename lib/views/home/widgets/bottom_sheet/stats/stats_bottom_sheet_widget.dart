import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/feature_flags_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_display_provider.dart';
import 'package:medito/providers/streak_circle_provider.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../row_item_widget.dart';
import 'package:medito/utils/utils.dart';

class StatsBottomSheetWidget extends ConsumerStatefulWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  ConsumerState<StatsBottomSheetWidget> createState() =>
      _StatsBottomSheetWidgetState();
}

class _StatsBottomSheetWidgetState extends ConsumerState<StatsBottomSheetWidget>
    with SingleTickerProviderStateMixin {
  bool _isCardVisible = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _fadeAndHideCard() {
    _animationController.forward();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isCardVisible = false;
        });
        ref.read(streakCircleProvider.notifier).markAsSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var statsAsync = ref.watch(statsProvider);
    var hasSeenStreakCircle = ref.watch(streakCircleProvider);

    return SafeArea(
      child: Container(
        decoration: bottomSheetBoxDecorationForTheme(context),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              height16,
              const HandleBarWidget(),
              height16,
              if (_isCardVisible)
                hasSeenStreakCircle.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (seen) {
                    if (seen) return const SizedBox.shrink();
                    return AnimatedOpacity(
                      opacity: _animation.value,
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withAlpha(
                                    ((0.1).clamp(0.0, 1.0) * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 1,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MeditoIcon(
                                    assetName: MeditoIcons.fire,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .statsWelcomeTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: dmSans,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)!
                                    .statsWelcomeMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontFamily: dmSans,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: _fadeAndHideCard,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                  ),
                                  child: Text(
                                      AppLocalizations.of(context)!.gotIt,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontSize: 14,
                                          )),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              statsAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                error: (error, stack) {
                  // If there was a previous successful state, display that instead of the error
                  if (statsAsync.hasValue) {
                    final stats = statsAsync.value!;
                    return _statsList(context, stats, ref);
                  } else {
                    // If there's no previous data, show the actual error state
                    return Center(
                      child: GestureDetector(
                        onTap: () => ref.read(statsProvider.notifier).refresh(),
                        child: MeditoIcon(
                          assetName: MeditoIcons.help,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }
                },
                data: (stats) {
                  // If the stats have a zero 'updated' timestamp, they're either initial empty stats
                  // or they haven't been properly fetched yet
                  final isPossiblyStillLoading = stats.updated == 0;

                  if (isPossiblyStillLoading) {
                    // Only try to refresh if it's the initial load
                    Future.microtask(
                        () => ref.read(statsProvider.notifier).refresh());
                    return const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  return _statsList(context, stats, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String title, String value) {
    return RowItemWidget(
      icon: MeditoHugeIcon(icon: title),
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailingIconSize: 20,
      title: value,
      subTitle: title,
      hasUnderline: true,
      isTrailingIcon: false,
      titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: dmSans,
          ),
    );
  }

  Widget _buildStreakFreezeRow(
      BuildContext context, LocalAllStats stats, WidgetRef ref) {
    final isStreakFreezeEnabled =
        ref.watch(featureFlagsProvider).isStreakFreezeEnabled;

    if (!isStreakFreezeEnabled) {
      return const SizedBox.shrink();
    }

    final currentFreezes = stats.streakFreezes ?? 0;
    final maxFreezes = stats.maxStreakFreezes ?? 0;

    return RowItemWidget(
      icon: MeditoIcon(
        assetName: MeditoIcons.snow,
        color: Theme.of(context).colorScheme.onSurface,
        size: 20,
      ),
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailingIconSize: 20,
      title: '$currentFreezes / $maxFreezes',
      subTitle: 'Streak Freezes',
      hasUnderline: true,
      isTrailingIcon: false,
      titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: dmSans,
          ),
    );
  }

  String _formatTotalTimeListened(int milliseconds) {
    var hours = milliseconds ~/ (1000 * 60 * 60);
    var minutes = (milliseconds % (1000 * 60 * 60)) ~/ (1000 * 60);

    if (hours > 0) {
      var hourText = hours == 1
          ? AppLocalizations.of(context)!.hourFull
          : AppLocalizations.of(context)!.hoursFull;
      var minuteText = minutes == 1
          ? AppLocalizations.of(context)!.minute
          : AppLocalizations.of(context)!.minutes;
      return '$hours $hourText ${minutes.toString().padLeft(2, '0')} $minuteText';
    } else {
      var minuteText = minutes == 1
          ? AppLocalizations.of(context)!.minute
          : AppLocalizations.of(context)!.minutes;
      return '$minutes $minuteText';
    }
  }

  Column _statsList(
    BuildContext context,
    LocalAllStats stats,
    WidgetRef ref,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              _buildStatRow(
                context,
                AppLocalizations.of(context)!.consistencyScore,
                '${(stats.consistencyScore * 100).round()}%',
              ),
              _buildStatRow(
                  context,
                  AppLocalizations.of(context)!.currentStreak,
                  '${stats.streakCurrent} ${stats.streakCurrent == 1 ? AppLocalizations.of(context)!.day : AppLocalizations.of(context)!.days}'),
              _buildStatRow(
                  context,
                  AppLocalizations.of(context)!.longestStreak,
                  '${stats.streakLongest} ${stats.streakLongest == 1 ? AppLocalizations.of(context)!.day : AppLocalizations.of(context)!.days}'),
              _buildStatRow(
                  context,
                  AppLocalizations.of(context)!.totalTracksCompleted,
                  '${stats.totalTracksCompleted}'),
              _buildStatRow(
                  context,
                  AppLocalizations.of(context)!.totalTimeListened,
                  _formatTotalTimeListened(stats.totalTimeListened)),
              _buildStreakFreezeRow(context, stats, ref),
              _buildStreakCircleDisplayPreference(context, ref),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(
                    text: AppLocalizations.of(context)!.shareStatsText,
                  )),
              icon: MeditoIcon(
                assetName: MeditoIcons.shareAndroid,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                AppLocalizations.of(context)!.share,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCircleDisplayPreference(
      BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Consumer(
        builder: (context, ref, _) {
          final displayTypeAsync = ref.watch(streakCircleDisplayProvider);

          return displayTypeAsync.when(
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (displayType) {
              final isStreakSelected =
                  displayType == StreakCircleDisplayType.currentStreak;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isStreakSelected,
                      onChanged: (value) {
                        final newType = value == true
                            ? StreakCircleDisplayType.currentStreak
                            : StreakCircleDisplayType.consistencyScore;
                        ref
                            .read(streakCircleDisplayProvider.notifier)
                            .setDisplayType(newType);
                        showSnackBar(
                            context,
                            AppLocalizations.of(context)!
                                .displayPreferenceSaved);
                      },
                      activeColor: ColorConstants.lightPurple,
                      checkColor: Theme.of(context).colorScheme.onPrimary,
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacityValue(0.6),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.alwaysShowStreakOnHomepage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontFamily: dmSans,
                          ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
