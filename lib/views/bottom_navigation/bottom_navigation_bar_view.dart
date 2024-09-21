import 'dart:async';

import 'package:medito/constants/constants.dart';
import 'package:medito/providers/fcm_token_provider.dart';
import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/settings/settings_screen.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/views/player/widgets/bottom_actions/bottom_action_bar.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  const BottomNavigationBarView({Key? key}) : super(key: key);

  @override
  ConsumerState<BottomNavigationBarView> createState() => _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState extends ConsumerState<BottomNavigationBarView> {
  var _currentPageIndex = 0;

  final _pages = [
    const HomeView(),
    ExploreView(),
    const SettingsScreen(), 
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveFCMToken();
    });
  }

  Future<void> _saveFCMToken() async {
    await ref.read(fcmTokenProvider)();
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
          leftItem: BottomActionBarItem(
            child: Icon(
              _currentPageIndex == 0 ? Icons.home : Icons.home_outlined,
              color: _currentPageIndex == 0 ? ColorConstants.lightPurple : ColorConstants.walterWhite,
            ),
            onTap: () => _onDestinationSelected(0),
          ),
          leftCenterItem: BottomActionBarItem(
            child: Icon(
              _currentPageIndex == 1 ? Icons.explore : Icons.explore_outlined,
              color: _currentPageIndex == 1 ? ColorConstants.lightPurple : ColorConstants.walterWhite,
            ),
            onTap: () => _onDestinationSelected(1),
          ),
          rightItem: BottomActionBarItem(
            child: Icon(
              _currentPageIndex == 2 ? Icons.settings : Icons.settings_outlined,
              color: _currentPageIndex == 2 ? ColorConstants.lightPurple : ColorConstants.walterWhite,
            ),
            onTap: () => _onDestinationSelected(2),
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
    setState(() {
      _currentPageIndex = index;
    });
  }
}
