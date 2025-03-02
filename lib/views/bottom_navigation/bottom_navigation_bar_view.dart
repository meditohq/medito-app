import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_freeze_suggestion_provider.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/streak_freeze_suggestion_widget.dart';
import 'package:medito/views/path/path_view.dart';
import 'package:medito/views/player/widgets/bottom_actions/bottom_action_bar.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/providers/feature_flags_provider.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  const BottomNavigationBarView({super.key});

  @override
  ConsumerState<BottomNavigationBarView> createState() =>
      _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState
    extends ConsumerState<BottomNavigationBarView> {
  var _currentPageIndex = 0;
  final _searchFocusNode = FocusNode();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeView(),
      ExploreView(searchFocusNode: _searchFocusNode),
      const JourneyView(),
      const SettingsScreen(),
    ];

    _initializeStats();
  }

  Future<void> _initializeStats() async {
    // First refresh stats
    await ref.read(statsProvider.notifier).refresh();

    // Only check for streak freeze suggestions after stats are loaded
    ref
        .read(streakFreezeSuggestionProvider.notifier)
        .checkForStreakFreezeSuggestion();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for streak freeze suggestions
    ref.listen<StreakFreezeSuggestionState>(
      streakFreezeSuggestionProvider,
      (previous, current) {
        // Check if streak freeze feature is enabled
        final isStreakFreezeEnabled =
            ref.read(featureFlagsProvider).isStreakFreezeEnabled;

        if (isStreakFreezeEnabled &&
            current.shouldShowSuggestion &&
            current.stats != null &&
            (previous == null || !previous.shouldShowSuggestion)) {
          // Show the suggestion bottom sheet
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showStreakFreezeSuggestion(context, current.stats!);

            // Mark as handled after showing
            ref
                .read(streakFreezeSuggestionProvider.notifier)
                .markSuggestionAsHandled();
          });
        }
      },
    );

    return PopScope(
      canPop: _currentPageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onDestinationSelected(0);
      },
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: BottomActionBar(
          layout: BottomActionBarLayout.homePage,
          leftItem: BottomActionBarItem(
            child: HugeIcon(
              icon: HugeIcons.solidRoundedHome01,
              color: _currentPageIndex == 0
                  ? ColorConstants.lightPurple
                  : ColorConstants.white,
            ),
            onTap: () => _onDestinationSelected(0),
          ),
          leftCenterItem: BottomActionBarItem(
            child: GestureDetector(
              onDoubleTap: () {
                if (_currentPageIndex == 1) {
                  _searchFocusNode.requestFocus();
                } else {
                  _onDestinationSelected(1);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _searchFocusNode.requestFocus();
                  });
                }
              },
              child: HugeIcon(
                icon: HugeIcons.solidRoundedSearch01,
                color: _currentPageIndex == 1
                    ? ColorConstants.lightPurple
                    : ColorConstants.white,
              ),
            ),
            onTap: () => _onDestinationSelected(1),
          ),
          rightCenterItem: BottomActionBarItem(
            child: HugeIcon(
              icon: HugeIcons.solidRoundedRoad02,
              color: _currentPageIndex == 2
                  ? ColorConstants.lightPurple
                  : ColorConstants.white,
            ),
            onTap: () => _onDestinationSelected(2),
          ),
          rightItem: BottomActionBarItem(
            child: HugeIcon(
              icon: HugeIcons.solidRoundedSettings01,
              color: _currentPageIndex == 3
                  ? ColorConstants.lightPurple
                  : ColorConstants.white,
            ),
            onTap: () => _onDestinationSelected(3),
          ),
        ),
        body: IndexedStack(
          index: _currentPageIndex,
          children: _pages,
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (_currentPageIndex == 1 && index != 1) {
      _searchFocusNode.unfocus();
    }
    setState(() {
      _currentPageIndex = index;
    });
  }

  void _showStreakFreezeSuggestion(BuildContext context, LocalAllStats stats) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => StreakFreezeSuggestionWidget(
        stats: stats,
        onUseFreeze: () async {
          await ref
              .read(streakFreezeSuggestionProvider.notifier)
              .useStreakFreeze();
        },
      ),
    );
  }
}
