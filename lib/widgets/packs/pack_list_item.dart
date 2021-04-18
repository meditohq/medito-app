import 'package:Medito/network/packs/packs_response.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';

class PackListItemWidget extends StatelessWidget {
  final PackImageListItemData data;

  PackListItemWidget(this.data);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          _getListItemLeadingImageWidget(),
          Container(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _getTitle(context),
                Container(height: 4),
                _getSubtitle(context)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Text _getSubtitle(BuildContext context) =>
      Text(data.subtitle ?? '', style: Theme.of(context).textTheme.subtitle1);

  Text _getTitle(BuildContext context) =>
      Text(data.title, style: Theme.of(context).textTheme.headline4);

  Widget _getListItemLeadingImageWidget() => ClipRRect(
        borderRadius: BorderRadius.circular(3.0),
        child: Container(
          color: parseColor(data.colorPrimary),
          child: SizedBox(
              height: data.coverSize,
              width: data.coverSize,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: data.icon ?? getNetworkImageWidget(data.cover),
              )),
        ),
      );
}

class PackImageListItemData {
  String title;
  String subtitle;
  String cover;
  String colorPrimary;
  double coverSize;
  Widget icon;

  PackImageListItemData(
      {this.title,
      this.subtitle,
      this.colorPrimary,
      this.cover,
      this.coverSize,
      this.icon});
}
