import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:collection/collection.dart';

class FilterWidget extends StatelessWidget {
  const FilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var items = [
      '💤 Sleep',
      '🚨 Emergency',
      '❤️ Relationships',
      '☁︎ Breathing',
      '☀️ Daily',
      '⏳ Timer',
      '📚 Courses',
      '🏆 Challenges',
    ];

    var row1 = items.take(items.length ~/ 2).toList();
    var row2 = items.skip(items.length ~/ 2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filterListView(row1),
            _filterListView(row2),
          ],
        ),
      ),
    );
  }

  Padding _filterListView(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          itemCount: items.length,
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: ColorConstants.onyx,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    EdgeInsets.only(left: 15, right: 15, bottom: 10, top: 6),
                child: Text(
                  items[index],
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
