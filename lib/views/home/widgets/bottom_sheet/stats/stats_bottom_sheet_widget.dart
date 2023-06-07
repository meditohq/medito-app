import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

import '../row_item_widget.dart';

class StatsBottomSheetWidget extends StatelessWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableSheetWidget(
      child: (scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: 4,
                itemBuilder: (BuildContext context, int index) {
                  return RowItemWidget(
                    leadingIcon: getLeadingIconPath('ic_help'),
                    title: 'element.title $index',
                    subTitle: 'Subtitle $index',
                    isShowUnderline: index < 4,
                    isTrailingIcon: false,
                    titleStyle: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontSize: 18),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String getLeadingIconPath(String path) {
    if (path == 'ic_help') {
      return AssetConstants.icHelpCircle;
    } else if (path == 'ic_email') {
      return AssetConstants.icHelpCircle;
    } else if (path == 'ic_medito') {
      return AssetConstants.icMedito;
    }

    return AssetConstants.icMedito;
  }
}
