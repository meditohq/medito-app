import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

import '../row_item_widget.dart';

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
                    iconCodePoint: element.icon,
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
}
