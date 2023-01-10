import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class SessionButtons extends StatefulWidget {
  const SessionButtons({Key? key}) : super(key: key);

  @override
  State<SessionButtons> createState() => _SessionButtonsState();
}

class _SessionButtonsState extends State<SessionButtons> {
  Map<String, List<String>> data = {
    'Will': ['5 mins', '10 min'],
    'Bob': [
      '5 mins',
      '10 min',
      '10 min',
      '10 min',
      '10 min',
      '10 min',
      '10 min',
      '10 min',
      '15 min'
    ],
    'Steve': ['5 mins', '10 min', '15 min', '40 min']
  };

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: data.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 20),
              Text(data.keys.toList().elementAt(i).toString()),
              Container(height: 8),
              GridView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: data.values.elementAt(i).length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    childAspectRatio: 3.0,
                    crossAxisCount: 2,
                  ),
                  itemBuilder: (_, int index) {
                    return _getGridItem(i, index);
                  })
            ],
          );
        });
  }

  Widget _getGridItem(int i, int index) => Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: MeditoColors.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(Radius.circular(20))),
      child: Text(data.values.elementAt(i).elementAt(index).toString()));
}
