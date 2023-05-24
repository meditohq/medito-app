import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';

class FilterWidget extends StatelessWidget {
  const FilterWidget({super.key, required this.chips});
  final List<HomeChipsModel> chips;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filterListView(chips.last.line1),
            _filterListView(chips.first.line2),
          ],
        ),
      ),
    );
  }

  Padding _filterListView(List<HomeChipsItemsModel> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        height: 45,
        child: ListView.builder(
          itemCount: items.length,
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: ColorConstants.onyx,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    EdgeInsets.only(left: 15, right: 15, bottom: 10, top: 6),
                child: Text(
                  items[index].label,
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
