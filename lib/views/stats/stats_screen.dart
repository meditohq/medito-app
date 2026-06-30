import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_display_provider.dart';
import 'package:medito/widgets/dialogs/medito_dialog.dart';
import 'package:medito/widgets/dialogs/medito_dialog_buttons.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/meditation_calendar_widget.dart';
import 'package:medito/views/settings/restore_stats_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const StatsScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showConsistencyScoreInfo() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => MeditoDialog(
        title: l10n.consistencyScoreInfoTitle,
        content: MeditoDialogBody(l10n.consistencyScoreInfoMessage),
        actions: [
          MeditoDialogPrimaryButton(
            label: l10n.gotIt,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeditoAppBarSmall(
        hasBackButton: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: padding16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabItem(
                      0,
                      AppLocalizations.of(context)!.stats,
                    ),
                  ),
                  Expanded(
                    child: _buildTabItem(
                      1,
                      AppLocalizations.of(context)!.history,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStatsTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final theme = Theme.of(context);
    final isSelected = _tabController.index == index;
    final selectedColor = theme.colorScheme.onSurface;
    final unselectedColor = theme.colorScheme.onSurface.withOpacityValue(0.5);

    return InkWell(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacityValue(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: dmSans,
                color: isSelected ? selectedColor : unselectedColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    var statsAsync = ref.watch(statsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
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
                        child: Semantics(
                          label: AppLocalizations.of(context)!.refresh,
                          button: true,
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(statsProvider.notifier).refresh(),
                            child: ExcludeSemantics(
                              child: MeditoIcon(
                                assetName: MeditoIcons.help,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                data: (stats) {
                  return _statsList(context, stats, ref);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    var statsAsync = ref.watch(statsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
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
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) {
                  if (stats.updated == 0) return const SizedBox.shrink();
                  return MeditationCalendarWidget(stats: stats);
                },
              ),
              const SizedBox(height: 16),
            ],
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
    VoidCallback? onTap,
  }) {
    return RowItemWidget(
      icon: MeditoRemoteIcon(icon: title),
      iconColor: Theme.of(context).colorScheme.onSurface,
      trailingIconSize: 20,
      title: value,
      subTitle: title,
      hasUnderline: hasUnderline,
      isTrailingIcon: onTap != null,
      trailingIcon: Icons.info_outline,
      onTap: onTap,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacityValue(0.08),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildStatRow(
                context,
                AppLocalizations.of(context)!.consistencyScore,
                '${(stats.consistencyScore * 100).round()}%',
                onTap: _showConsistencyScoreInfo,
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
                hasUnderline: false,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: AppLocalizations.of(context)!.shareStatsText),
              ),
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
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        _buildStreakCircleDisplayPreference(context, ref),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RestoreStatsScreen()),
            ),
            icon: Icon(
              Icons.restore_outlined,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacityValue(0.7),
            ),
            label: Text(
              AppLocalizations.of(context)!.restorePreviousStats,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacityValue(0.7),
              ),
            ),
          ),
        ),
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
            error: (_, _) => const SizedBox.shrink(),
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

              return MergeSemantics(
                child: InkWell(
                  onTap: handleToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isStreakSelected,
                            onChanged: (_) => handleToggle(),
                            activeColor: context.brandPurple,
                            checkColor: Theme.of(context).colorScheme.onPrimary,
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacityValue(0.6),
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
                            AppLocalizations.of(
                              context,
                            )!.alwaysShowStreakOnHomepage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: 14, fontFamily: dmSans),
                          ),
                        ),
                      ],
                    ),
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
