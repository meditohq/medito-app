import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

Widget getStreakTile(Future future, String title,
    {Function onClick, UnitType optionalText}) {
  return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        var unit;
        if (snapshot.hasData) {
          var value = int.parse(snapshot?.data);
          unit = getUnits(optionalText, value);
        }

        return GestureDetector(
          onTap: onClick,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                color: MeditoColors.darkColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(height: 4),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                        style: Theme.of(context).textTheme.title),
                    Row(
                      textBaseline: TextBaseline.alphabetic,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      children: <Widget>[
                        Text(
                          _formatSnapshotData(snapshot),
                          style: Theme.of(context)
                              .textTheme
                              .title
                              .copyWith(fontSize: 34),
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(unit ?? ''),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      });
}

String _formatSnapshotData(AsyncSnapshot<String> snapshot) {
  var value = snapshot?.data ?? '0';
  if (value.length > 5) {
    return '999+';
  }
  return value;
}

//Widget wrapWithStreakInkWell(Widget w) {
//  return Material(
//    color: Colors.white.withOpacity(0.0),
//    child: InkWell(
//        splashColor: MeditoColors.lightColor,
//        onTap: () => _onStreakTap(),
//        borderRadius: BorderRadius.circular(16.0),
//        child: w),
//  );
//}
