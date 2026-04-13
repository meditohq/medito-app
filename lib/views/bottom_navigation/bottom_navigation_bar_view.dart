import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/path/path_view.dart';
import 'package:medito/views/player/widgets/bottom_actions/bottom_action_bar.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  const BottomNavigationBarView({super.key});

  @override
  ConsumerState<BottomNavigationBarView> createState() =>
      _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState
    extends ConsumerState<BottomNavigationBarView> {
  late var _currentPageIndex;
  final _searchFocusNode = FocusNode();
  final _exploreViewKey = GlobalKey<ExploreViewState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getInt(SharedPreferenceConstants.lastMainTabIndex) ?? 0;
    _currentPageIndex = saved <= 1 ? saved : 0;
    _pages = [
      const HomeView(),
      ExploreView(key: _exploreViewKey, searchFocusNode: _searchFocusNode),
      const JourneyView(),
      const SettingsScreen(),
    ];

    _initializeStats();
  }

  Future<void> _initializeStats() async {
    await ref.read(statsProvider.notifier).refresh();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          leftItem: _buildHomeNavigationItem(),
          leftCenterItem: _buildSearchNavigationItem(),
          rightCenterItem: _buildJourneyNavigationItem(),
          rightItem: _buildSettingsNavigationItem(),
        ),
        body: IndexedStack(
          index: _currentPageIndex,
          children: _pages,
        ),
      ),
    );
  }

  BottomActionBarItem _buildHomeNavigationItem() {
    final l10n = AppLocalizations.of(context)!;

    return BottomActionBarItem(
      child: MeditoIcon(
        assetName: MeditoIcons.home,
        color: _currentPageIndex == 0
            ? ColorConstants.lightPurple
            : Theme.of(context).colorScheme.onSurface,
      ),
      onTap: () => _onDestinationSelected(0),
      semanticLabel: l10n.home,
    );
  }

  BottomActionBarItem _buildSearchNavigationItem() {
    final l10n = AppLocalizations.of(context)!;

    return BottomActionBarItem(
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
        child: MeditoIcon(
          assetName: MeditoIcons.book,
          color: _currentPageIndex == 1
              ? ColorConstants.lightPurple
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () => _onDestinationSelected(1),
      semanticLabel: l10n.explore,
    );
  }

  BottomActionBarItem _buildJourneyNavigationItem() {
    final l10n = AppLocalizations.of(context)!;

    return BottomActionBarItem(
      child: MeditoIcon(
        assetName: MeditoIcons.road,
        color: _currentPageIndex == 2
            ? ColorConstants.lightPurple
            : Theme.of(context).colorScheme.onSurface,
      ),
      onTap: () => _onDestinationSelected(2),
      semanticLabel: l10n.path,
    );
  }

  BottomActionBarItem _buildSettingsNavigationItem() {
    final l10n = AppLocalizations.of(context)!;

    return BottomActionBarItem(
      child: MeditoIcon(
        assetName: MeditoIcons.settings,
        color: _currentPageIndex == 3
            ? ColorConstants.lightPurple
            : Theme.of(context).colorScheme.onSurface,
      ),
      onTap: () => _onDestinationSelected(3),
      semanticLabel: l10n.settings,
    );
  }

  void _onDestinationSelected(int index) {
    if (_currentPageIndex == 1 && index != 1) {
      _searchFocusNode.unfocus();
    }

    setState(() {
      _currentPageIndex = index;
    });

    if (index <= 1) {
      ref.read(sharedPreferencesProvider)
          .setInt(SharedPreferenceConstants.lastMainTabIndex, index);
    }

    // Load explore data only on the first visit to the explore tab
    if (index == 1) {
      _exploreViewKey.currentState?.loadData();
    }
  }

}
