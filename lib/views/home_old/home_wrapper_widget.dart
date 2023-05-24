import 'package:Medito/network/user/user_utils.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/views/home/home_view.dart';
import 'package:Medito/views/packs/packs_screen.dart';
import 'package:flutter/material.dart';
import 'package:Medito/constants/constants.dart';

class HomeWrapperWidget extends StatefulWidget {
  const HomeWrapperWidget({Key? key}) : super(key: key);

  @override
  _HomeWrapperWidgetState createState() => _HomeWrapperWidgetState();
}

class _HomeWrapperWidgetState extends State<HomeWrapperWidget> {
  var _currentIndex = 0;
  final _messengerKey = GlobalKey<ScaffoldState>();
  var _deletingCache = true;
  bool _hasOpened = false;

  @override
  void initState() {
    firstOpenOperations().then((hasOpened) {
      _hasOpened = hasOpened;
      setState(() {
        _deletingCache = false;
      });
    });

    // update stats for any sessions that were listened in the background and after the app was killed
    updateStatsFromBg();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return _deletingCache
        ? _getLoadingWidget()
        : Scaffold(
            key: _messengerKey,
            body: IndexedStack(
              index: _currentIndex,
              children: [HomeView(), PacksScreen()],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: ColorConstants.softGrey,
                border: Border(
                  top: BorderSide(color: ColorConstants.softGrey, width: 2.0),
                ),
              ),
              child: BottomNavigationBar(
                selectedLabelStyle:
                    textTheme.displayLarge?.copyWith(fontSize: 12),
                unselectedLabelStyle:
                    textTheme.displayMedium?.copyWith(fontSize: 12),
                selectedItemColor: ColorConstants.walterWhite,
                unselectedItemColor: ColorConstants.newGrey,
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                items: [
                  BottomNavigationBarItem(
                    tooltip: 'Home',
                    icon: Icon(
                      Icons.home_outlined,
                      size: 20,
                    ),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.format_list_bulleted_outlined,
                      size: 20,
                    ),
                    tooltip: 'Packs',
                    label: 'Packs',
                  ),
                ],
              ),
            ),
          );
  }

  Widget _getLoadingWidget() {
    return Center(
      child: CircularProgressIndicator(
        backgroundColor: Colors.black,
        valueColor: AlwaysStoppedAnimation<Color>(
          ColorConstants.walterWhite,
        ),
      ),
    );
  }

  void _onTabTapped(int value) {
    setState(() {
      _currentIndex = value;
    });
  }
}
