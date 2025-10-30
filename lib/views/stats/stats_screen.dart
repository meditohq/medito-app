import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/feature_flags_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_display_provider.dart';
import 'package:medito/providers/streak_circle_provider.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:share_plus/share_plus.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
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
    _animation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_animationController);
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

    return Scaffold(
      appBar: MeditoAppBarSmall(
        title: AppLocalizations.of(context)!.stats,
        hasBackButton: false,
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0.1),
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
                                    HugeIcon(
                                      icon: HugeIcons.solidRoundedFire,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!
                                            .statsWelcomeTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: dmSans,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!
                                      .statsWelcomeMessage,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontSize: 14,
                                        height: 1.4,
                                        fontFamily: dmSans,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: _fadeAndHideCard,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context)!.gotIt,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 14,
                                          ),
                                    ),
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
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (error, stack) {
                    if (statsAsync.hasValue) {
                      final stats = statsAsync.value!;
                      return _statsList(context, stats, ref);
                    } else {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(statsProvider.notifier).refresh(),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedHelpCircle,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  data: (stats) {
                    final isPossiblyStillLoading = stats.updated == 0;

                    if (isPossiblyStillLoading) {
                      Future.microtask(
                        () => ref.read(statsProvider.notifier).refresh(),
                      );
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    return _statsList(context, stats, ref);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String title,
    String value, {
    bool hasUnderline = true,
  }) {
    return RowItemWidget(
      icon: MeditoHugeIcon(icon: title),
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailingIconSize: 20,
      title: value,
      subTitle: title,
      hasUnderline: hasUnderline,
      isTrailingIcon: false,
      titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: dmSans,
          ),
    );
  }

  Widget _buildStreakFreezeRow(
    BuildContext context,
    LocalAllStats stats,
    WidgetRef ref,
  ) {
    final isStreakFreezeEnabled =
        ref.watch(featureFlagsProvider).isStreakFreezeEnabled;

    if (!isStreakFreezeEnabled) {
      return const SizedBox.shrink();
    }

    final currentFreezes = stats.streakFreezes ?? 0;
    final maxFreezes = stats.maxStreakFreezes ?? 0;

    return RowItemWidget(
      icon: HugeIcon(
        icon: HugeIcons.solidStandardSnow,
        color: Theme.of(context).colorScheme.onSurface,
        size: 20,
      ),
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailingIconSize: 20,
      title: '$currentFreezes / $maxFreezes',
      subTitle: 'Streak Freezes',
      hasUnderline: false,
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

  Column _statsList(BuildContext context, LocalAllStats stats, WidgetRef ref) {
    final isStreakFreezeEnabled =
        ref.watch(featureFlagsProvider).isStreakFreezeEnabled;
    final shouldShowTotalTimeUnderline = isStreakFreezeEnabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              width: 1,
            ),
          ),
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
                '${stats.streakCurrent} ${stats.streakCurrent == 1 ? AppLocalizations.of(context)!.day : AppLocalizations.of(context)!.days}',
              ),
              _buildStatRow(
                context,
                AppLocalizations.of(context)!.longestStreak,
                '${stats.streakLongest} ${stats.streakLongest == 1 ? AppLocalizations.of(context)!.day : AppLocalizations.of(context)!.days}',
              ),
              _buildStatRow(
                context,
                AppLocalizations.of(context)!.totalTracksCompleted,
                '${stats.totalTracksCompleted}',
              ),
              _buildStatRow(
                context,
                AppLocalizations.of(context)!.totalTimeListened,
                _formatTotalTimeListened(stats.totalTimeListened),
                hasUnderline: shouldShowTotalTimeUnderline,
              ),
              _buildStreakFreezeRow(context, stats, ref),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Share.share(AppLocalizations.of(context)!.shareStatsText),
              icon: HugeIcon(
                icon: HugeIcons.solidRoundedShare08,
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
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        _buildStreakCircleDisplayPreference(context, ref),
      ],
    );
  }

  Widget _buildStreakCircleDisplayPreference(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
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

              void handleToggle() {
                final newType = !isStreakSelected
                    ? StreakCircleDisplayType.currentStreak
                    : StreakCircleDisplayType.consistencyScore;
                ref
                    .read(streakCircleDisplayProvider.notifier)
                    .setDisplayType(newType);
              }

              return InkWell(
                onTap: handleToggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isStreakSelected,
                          onChanged: (_) => handleToggle(),
                          activeColor: ColorConstants.lightPurple,
                          checkColor: Theme.of(context).colorScheme.onPrimary,
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
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
                          AppLocalizations.of(context)!
                              .alwaysShowStreakOnHomepage,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontFamily: dmSans,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
