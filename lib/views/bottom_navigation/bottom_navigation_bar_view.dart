import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/home/home_view.dart';
import 'package:Medito/views/explore/explore_view.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomNavigationBarView extends ConsumerStatefulWidget {
  BottomNavigationBarView({super.key});

  @override
  ConsumerState<BottomNavigationBarView> createState() =>
      _BottomNavigationBarViewState();
}

class _BottomNavigationBarViewState
    extends ConsumerState<BottomNavigationBarView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  int currentPageIndex = 0;
  late PageController pageController;
  List<NavigationDestination> navigationBarItems = [
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
    pageController = PageController(initialPage: currentPageIndex);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    if (connectivityStatus == ConnectivityStatus.isDisconnected) {
      return ConnectivityErrorWidget();
    }

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onDestinationSelected,
        indicatorColor: ColorConstants.lightPurple,
        backgroundColor: ColorConstants.ebony,
        selectedIndex: currentPageIndex,
        destinations: navigationBarItems,
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: _onDestinationSelected,
        children: <Widget>[HomeView(), ExploreView()],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      currentPageIndex = index;
      pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    });
  }

  @override
  bool get wantKeepAlive => true;
}
