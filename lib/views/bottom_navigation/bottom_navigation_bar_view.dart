import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/views/explore/widgets/explore_view.dart';
import 'package:Medito/views/home/home_view.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class BottomNavigationBarView extends StatefulWidget {
  @override
  _BottomNavigationBarViewState createState() =>
      _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState extends State<BottomNavigationBarView> {
  int _currentPageIndex = 0;
  late PageController _pageController;
  late final StreamSubscription _subscription;
  var _isConnected = true;

  final List<Widget> _pages = [
    HomeView(),
    ExploreView(),
  ];

  final List<NavigationDestination> _navigationBarItems = [
    NavigationDestination(
      selectedIcon: Icon(Icons.home),
      icon: Icon(Icons.home_outlined),
      label: StringConstants.home,
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.explore),
      icon: Icon(Icons.explore_outlined),
      label: StringConstants.explore,
    ),
  ];

  @override
  void initState() {
    _pageController = PageController(initialPage: _currentPageIndex);
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    });
    super.initState();
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
        body: _isConnected
            ? PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: NeverScrollableScrollPhysics(),
                children: _pages,
              )
            : ConnectivityErrorWidget(),
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
