import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class FilterWidget extends StatelessWidget {
  const FilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.start,
        alignment: WrapAlignment.start,
        spacing: 15,
        runSpacing: 10,
        runAlignment: WrapAlignment.start,
        children: List.generate(
          18,
          (int index) => Container(
            decoration: BoxDecoration(
              color: ColorConstants.onyx,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AssetConstants.icStreak,
                ),
                width4,
                Text(
                  'data',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ).toList(),
      ),
    );
  }
}
