import 'package:Medito/constants/constants.dart';
import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MenuBottomSheetWidget extends StatelessWidget {
  const MenuBottomSheetWidget({super.key, required this.homeMenuModel});
  final List<HomeMenuModel> homeMenuModel;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 1,
      expand: false,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: BoxDecoration(
            color: ColorConstants.onyx,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              height16,
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: ColorConstants.walterWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              height16,
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: homeMenuModel.length,
                  itemBuilder: (BuildContext context, int index) {
                    var element = homeMenuModel[index];

                    return ListTile(
                      horizontalTitleGap: 0,
                      leading: SvgPicture.asset(
                        getLeadingIconPath(element.icon),
                        height: 14,
                      ),
                      minVerticalPadding: 0,
                      title: Text('${element.title}'),
                    );
                  },
                ),
              ),
            ],
          ),
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
