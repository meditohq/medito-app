import 'dart:async';

import 'package:medito/constants/constants.dart';
import 'package:medito/providers/fcm_token_provider.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  const BottomNavigationBarView({Key? key}) : super(key: key);

  @override
  ConsumerState<BottomNavigationBarView> createState() => _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState extends ConsumerState<BottomNavigationBarView> {
  int _currentPageIndex = 0;
  late PageController _pageController;
  late final StreamSubscription _subscription;

  final List<Widget> _pages = [
    const HomeView(),
    ExploreView(),
  ];

  final List<NavigationDestination> _navigationBarItems = [
    const NavigationDestination(
      selectedIcon: Icon(Icons.home),
      icon: Icon(Icons.home_outlined),
      label: StringConstants.home,
    ),
    const NavigationDestination(
      selectedIcon: Icon(Icons.explore),
      icon: Icon(Icons.explore_outlined),
      label: StringConstants.explore,
    ),
  ];

  @override
  void initState() {
    _pageController = PageController(initialPage: _currentPageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveFCMToken();
    });
    super.initState();
  }

  Future<void> _saveFCMToken() async {
    await ref.read(fcmTokenProvider)();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPageIndex == 0,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) {
          return;
        }
        _onDestinationSelected(0);
      },
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: _onDestinationSelected,
          indicatorColor: ColorConstants.lightPurple,
          backgroundColor: ColorConstants.ebony,
          selectedIndex: _currentPageIndex,
          destinations: _navigationBarItems,
        ),
        body: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                children: _pages,
              ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentPageIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }
}
