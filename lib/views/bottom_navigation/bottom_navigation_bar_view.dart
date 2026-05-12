import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/path/path_view.dart';
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
  // Maps NavigationBar destination index -> page index in _pages.
  static const _pageIndexForDestination = [0, 1, 3];

  late int _currentPageIndex;
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final unselectedColor = colorScheme.onSurfaceVariant;
    final selectedColor = context.brandPurple;
    final selectedDestination = _pageIndexForDestination.indexOf(
      _currentPageIndex,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PopScope(
        canPop: _currentPageIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _onDestinationSelected(0);
        },
        child: Scaffold(
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedDestination >= 0 ? selectedDestination : 0,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            indicatorColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final baseStyle = Theme.of(context).textTheme.labelMedium;
              final color = states.contains(WidgetState.selected)
                  ? selectedColor
                  : unselectedColor;
              return baseStyle?.copyWith(color: color);
            }),
            onDestinationSelected: (index) =>
                _onDestinationSelected(_pageIndexForDestination[index]),
            destinations: [
              NavigationDestination(
                icon: MeditoIcon(
                  assetName: MeditoIcons.home,
                  color: unselectedColor,
                ),
                selectedIcon: MeditoIcon(
                  assetName: MeditoIcons.home,
                  color: selectedColor,
                ),
                label: l10n.home,
              ),
              NavigationDestination(
                icon: GestureDetector(
                  onDoubleTap: _onExploreDoubleTap,
                  child: MeditoIcon(
                    assetName: MeditoIcons.book,
                    color: unselectedColor,
                  ),
                ),
                selectedIcon: GestureDetector(
                  onDoubleTap: _onExploreDoubleTap,
                  child: MeditoIcon(
                    assetName: MeditoIcons.book,
                    color: selectedColor,
                  ),
                ),
                label: l10n.explore,
              ),
              NavigationDestination(
                icon: MeditoIcon(
                  assetName: MeditoIcons.settings,
                  color: unselectedColor,
                ),
                selectedIcon: MeditoIcon(
                  assetName: MeditoIcons.settings,
                  color: selectedColor,
                ),
                label: l10n.settings,
              ),
            ],
          ),
          body: IndexedStack(index: _currentPageIndex, children: _pages),
        ),
      ),
    );
  }

  void _onExploreDoubleTap() {
    if (_currentPageIndex == 1) {
      _searchFocusNode.requestFocus();
    } else {
      _onDestinationSelected(1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _onDestinationSelected(int index) {
    if (_currentPageIndex == 1 && index != 1) {
      _searchFocusNode.unfocus();
    }

    if (index != _currentPageIndex) {
      const tabTargets = {
        0: 'tab_home',
        1: 'tab_explore',
        3: 'tab_settings',
      };
      final target = tabTargets[index];
      if (target != null) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .logFirstActionAfterOnboardingIfNeeded(target),
        );
      }
    }

    setState(() {
      _currentPageIndex = index;
    });

    if (index <= 1) {
      ref
          .read(sharedPreferencesProvider)
          .setInt(SharedPreferenceConstants.lastMainTabIndex, index);
    }

    // Load explore data only on the first visit to the explore tab
    if (index == 1) {
      _exploreViewKey.currentState?.loadData();
    }
  }
}
