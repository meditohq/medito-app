import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SessionButtons extends StatelessWidget {
  final data = <String, List<String>>{
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
              Text(
                data.keys.toList().elementAt(i).toString(),
                style: Theme.of(context).primaryTextTheme.bodyText1?.copyWith(
                      color: MeditoColors.walterWhite,
                    ),
              ),
              height8,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  for (int eleIndex = 0;
                      eleIndex < data.values.elementAt(i).length;
                      eleIndex++)
                    _getGridItem(context, i, eleIndex)
                ],
              ),
              SizedBox(height: 30),
            ],
          );
        });
  }

  Container _getGridItem(BuildContext context, int i, int index) {
    var label = data.values.elementAt(i).elementAt(index).toString();
    // print(GoogleFonts.dmSans().fontFamily);
    return Container(
      width: 171,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MeditoColors.greyIsTheNewGrey,
        borderRadius: BorderRadius.all(
          Radius.circular(14),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .primaryTextTheme
            .bodyText1
            ?.copyWith(color: MeditoColors.walterWhite, fontFamily: DmMono),
      ),
    );
  }
}
