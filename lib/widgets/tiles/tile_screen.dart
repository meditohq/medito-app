import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class TileList extends StatefulWidget {
  TileList({Key key}) : super(key: key);

  @override
  TileListState createState() {
    return TileListState();
  }
}

class TileListState extends State<TileList> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MeditoColors.darkBGColor,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.network('https://img.icons8.com/ios/72/blood-sample.png', height: 54,),
            Expanded(
              child: ListView.builder(
                itemCount: 4,
                shrinkWrap: true,
                itemBuilder: (BuildContext context, int index) {
                  if (index < 3) {
                    return ListTile(
                      title: getHorizontalTile(),
                    );
                  } else
                    return twoColumnsTile();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget twoColumnsTile() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                wrapWithRowExpanded(getTile()),
                wrapWithRowExpanded(getTile()),
                wrapWithRowExpanded(getTile()),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                wrapWithRowExpanded(getTile()),
                wrapWithRowExpanded(getTile()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget wrapWithRowExpanded(Widget w) {
    return Row(
      children: <Widget>[
        Expanded(child: w),
      ],
    );
  }

  Widget getTile() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: Colors.red,
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            top: 16.0,
            right: 16.0,
            left: 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('This is it ', style: Theme.of(context).textTheme.title),
              Container(height: 16),
              Image.network('http://i.stack.imgur.com/ATMKk.png'),
            ],
          ),
        ),
      ),
    );
  }

  Widget getHorizontalTile() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: Colors.red,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('This is it ',
                        style: Theme.of(context).textTheme.title),
                    Text('This is it ',
                        style: Theme.of(context).textTheme.subhead),
                    FlatButton(
                      child: Text('This is it ',
                          style: Theme.of(context).textTheme.subhead),
                    )
                  ],
                ),
              ),
              Container(height: 16),
              Expanded(
                  child: Image.network(
                'http://i.stack.imgur.com/ATMKk.png',
                    width: 50,
                    height: 50
              )),
            ],
          ),
        ),
      ),
    );
  }
}
