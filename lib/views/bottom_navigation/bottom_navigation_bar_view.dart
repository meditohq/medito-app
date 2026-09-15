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
import 'package:medito/views/bottom_navigation/widgets/floating_nav_bar.dart';
import 'package:medito/views/bottom_navigation/widgets/floating_search_field.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/path/path_view.dart';
import 'package:medito/views/search/search_results.dart';
import 'package:medito/views/settings/settings_screen.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  const BottomNavigationBarView({super.key});

  @override
  ConsumerState<BottomNavigationBarView> createState() =>
      _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState
    extends ConsumerState<BottomNavigationBarView> {
  // Maps nav destination index -> page index in _pages.
  static const _pageIndexForDestination = [0, 1, 3];
  static const _searchDebounce = Duration(milliseconds: 500);

  late int _currentPageIndex;
  final _exploreViewKey = GlobalKey<ExploreViewState>();
  late final List<Widget> _pages;

  // Search expands in place: the nav capsule holds the field and results
  // overlay the current tab.
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getInt(SharedPreferenceConstants.lastMainTabIndex) ?? 0;
    _currentPageIndex = saved <= 1 ? saved : 0;
    _pages = [
      const HomeView(),
      ExploreView(key: _exploreViewKey),
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
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
        canPop: !_searchOpen && _currentPageIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_searchOpen) {
            _closeSearch();
          } else {
            _onDestinationSelected(0);
          }
        },
        child: Scaffold(
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          extendBody: true,
          bottomNavigationBar: FloatingNavBar(
            selectedIndex: selectedDestination >= 0 ? selectedDestination : 0,
            onSelected: (index) =>
                _onDestinationSelected(_pageIndexForDestination[index]),
            items: [
              FloatingNavItem(icon: MeditoIcons.home, label: l10n.home),
              FloatingNavItem(icon: MeditoIcons.book, label: l10n.explore),
              FloatingNavItem(icon: MeditoIcons.settings, label: l10n.settings),
            ],
            action: FloatingNavAction(
              icon: MeditoIcons.search,
              label: l10n.search,
              onTap: _openSearch,
            ),
            expanded: _searchOpen,
            expandedChild: FloatingSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            cancelLabel: l10n.cancel,
            onCancel: _closeSearch,
          ),
          body: Stack(
            children: [
              IndexedStack(index: _currentPageIndex, children: _pages),
              // Fades in over the tab; the tab underneath keeps its state.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _searchOpen
                    ? Material(
                        key: const ValueKey('search'),
                        color: theme.scaffoldBackgroundColor,
                        child: SafeArea(
                          bottom: false,
                          child: SearchResults(
                            query: _searchQuery,
                            onBeforeNavigate: _searchFocusNode.unfocus,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('tabs')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearch() {
    if (_searchOpen) return;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logFirstActionAfterOnboardingIfNeeded('search'),
    );
    unawaited(FirebaseAnalyticsService().logScreenView(screenName: 'Search'));
    setState(() => _searchOpen = true);
  }

  /// Empties the field but stays in search.
  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      // The search backend is ASCII-only.
      final asciiQuery = value.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
      setState(() => _searchQuery = asciiQuery);
    });
  }

  void _onDestinationSelected(int index) {
    if (index != _currentPageIndex) {
      const tabTargets = {0: 'tab_home', 1: 'tab_explore', 3: 'tab_settings'};
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
