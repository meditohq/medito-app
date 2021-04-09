import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class StatsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      child: ListView.builder(
        itemBuilder: (context, i) => statsItem(context, i),
        itemCount: 5,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
      ),
    );
  }

  Widget statsItem(BuildContext context, int index) {
    return Card(
      color: MeditoColors.moonlight,
      child: Column(
        children: [
          Text('Current Streak',
              style:
                  Theme.of(context).textTheme.headline6.copyWith(fontSize: 18)),
          Text('31', style: Theme.of(context).textTheme.headline1)
        ],
      ),
    );
  }
}
