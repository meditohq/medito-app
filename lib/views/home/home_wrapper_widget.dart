import 'package:flutter/material.dart';

import '../../network/user/user_utils.dart';
import 'package:Medito/constants/constants.dart';
import '../../utils/stats_utils.dart';
import '../btm_nav/home_widget.dart';
import '../packs/packs_screen.dart';

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
    return _deletingCache
        ? _getLoadingWidget()
        : Scaffold(
      key: _messengerKey,
      body: IndexedStack(
        index: _currentIndex,
        children:  [HomeWidget(_hasOpened), PackListWidget()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
                color: MeditoColors.softGrey,
                border: Border(
                  top: BorderSide(color: MeditoColors.softGrey, width: 2.0),
                ),
              ),
              child: BottomNavigationBar(
                selectedLabelStyle: Theme.of(context)
                    .textTheme
                    .headline1
                    ?.copyWith(fontSize: 12),
                unselectedLabelStyle: Theme.of(context)
                    .textTheme
                    .headline2
                    ?.copyWith(fontSize: 12),
                selectedItemColor: MeditoColors.walterWhite,
                unselectedItemColor: MeditoColors.newGrey,
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
            valueColor: AlwaysStoppedAnimation<Color>(MeditoColors.walterWhite)));
  }

  void _onTabTapped(int value) {
    setState(() {
      _currentIndex = value;
    });
  }

}
