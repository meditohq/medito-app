import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/views/bottom_navigation/widgets/medito_nav_bar.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/search/search_view.dart';
import 'package:medito/views/settings/settings_screen.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  const BottomNavigationBarView({super.key});

  @override
  ConsumerState<BottomNavigationBarView> createState() =>
      _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState
    extends ConsumerState<BottomNavigationBarView> {
  // Nav destination index == page index in _pages: Home, Explore, Search,
  // Settings. Search is a full tab (not an overlay), so it behaves like any
  // other tab: you leave it by switching tabs, and Android back returns Home.
  static const _homeIndex = 0;
  static const _exploreIndex = 1;
  static const _searchIndex = 2;

  late int _currentPageIndex;
  final _exploreViewKey = GlobalKey<ExploreViewState>();
  final _searchViewKey = GlobalKey<SearchViewState>();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getInt(SharedPreferenceConstants.lastMainTabIndex) ?? 0;
    // Only Home/Explore are restored on launch; never open straight into
    // Search or Settings.
    _currentPageIndex = saved <= _exploreIndex ? saved : _homeIndex;
    _pages = [
      const HomeView(),
      ExploreView(key: _exploreViewKey),
      SearchView(key: _searchViewKey),
      const SettingsScreen(),
    ];

    _initializeStats();
  }

  Future<void> _initializeStats() async {
    await ref.read(statsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;

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
        canPop: _currentPageIndex == _homeIndex,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _onDestinationSelected(_homeIndex);
        },
        child: Scaffold(
          // The nav bar is lifted to sit just above the keyboard (via the
          // bottom-inset padding below) rather than hiding behind it, so a tap
          // aimed at the Search tab hits the icon instead of the keyboard's
          // spacebar. resizeToAvoidBottomInset stays false so the Scaffold
          // doesn't also inset the body — padding the bar already reserves the
          // keyboard's height, shrinking the body to sit above it.
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            // While the keyboard is open the bar sits directly on top of it, so
            // drop the bar's bottom safe-area (home-indicator) inset — otherwise
            // it leaves a gap between the tabs and the keyboard.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: keyboardOpen,
              child: MeditoNavBar(
                selectedIndex: _currentPageIndex,
                onSelected: _onDestinationSelected,
                items: [
                  MeditoNavItem(icon: MeditoIcons.home, label: l10n.home),
                  MeditoNavItem(icon: MeditoIcons.book, label: l10n.explore),
                  MeditoNavItem(icon: MeditoIcons.search, label: l10n.search),
                  MeditoNavItem(
                    icon: MeditoIcons.settings,
                    label: l10n.settings,
                  ),
                ],
              ),
            ),
          ),
          body: IndexedStack(index: _currentPageIndex, children: _pages),
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    final entering = index != _currentPageIndex;

    // Leaving Search dismisses the keyboard so it doesn't linger over another
    // tab. (Entering Search focuses the field below.)
    if (index != _searchIndex) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    if (entering) {
      const tabTargets = {
        _homeIndex: 'tab_home',
        _exploreIndex: 'tab_explore',
        _searchIndex: 'search',
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

    if (index <= _exploreIndex) {
      ref
          .read(sharedPreferencesProvider)
          .setInt(SharedPreferenceConstants.lastMainTabIndex, index);
    }

    // Load explore data only on the first visit to the explore tab.
    if (index == _exploreIndex) {
      _exploreViewKey.currentState?.loadData();
    }

    // Selecting Search focuses the field so the user can type immediately;
    // re-tapping the active tab re-opens the keyboard too. The screen view is
    // logged only on actual entry, not on every re-tap.
    if (index == _searchIndex) {
      if (entering) {
        unawaited(
          FirebaseAnalyticsService().logScreenView(screenName: 'Search'),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchViewKey.currentState?.focusInput();
      });
    }
  }
}
