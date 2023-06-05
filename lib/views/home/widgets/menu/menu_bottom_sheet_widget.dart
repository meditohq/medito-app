import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';

import 'row_item_widget.dart';

class MenuBottomSheetWidget extends StatelessWidget {
  const MenuBottomSheetWidget({super.key, required this.homeMenuModel});
  final List<HomeMenuModel> homeMenuModel;

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
                itemCount: homeMenuModel.length,
                itemBuilder: (BuildContext context, int index) {
                  var element = homeMenuModel[index];

                  return RowItemWidget(
                    leadingIcon: getLeadingIconPath(element.icon),
                    title: element.title,
                    isShowUnderline: index < homeMenuModel.length - 1,
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
