import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

//ignore:prefer-match-file-name
class DownloadListItemWidget extends StatelessWidget {
  final PackImageListItemData data;

  const DownloadListItemWidget(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    var notNullAndNotEmpty = data.subtitle.isNotNullAndNotEmpty();

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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _getTitle(context),
                notNullAndNotEmpty ? Container(height: 4) : Container(),
                notNullAndNotEmpty ? _getSubtitle(context) : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Text _getSubtitle(BuildContext context) =>
      Text(data.subtitle ?? '', style: Theme.of(context).textTheme.titleMedium);

  Text _getTitle(BuildContext context) => Text(
        data.title ?? '',
        style: Theme.of(context).textTheme.headlineMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  Widget _getListItemLeadingImageWidget() => ClipRRect(
        borderRadius: BorderRadius.circular(3.0),
        child: Container(
          color: data.colorPrimary,
          child: SizedBox(
            height: data.coverSize,
            width: data.coverSize,
            child: _coverImageWidget(),
          ),
        ),
      );

  Padding _coverImageWidget() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: data.icon ??
          NetworkImageWidget(
            url: data.cover!,
            shouldCache: true,
          ),
    );
  }
}

class PackImageListItemData {
  String? title;
  String? subtitle;
  String? cover;
  String? backgroundImage;
  Color? colorPrimary;
  double? coverSize;
  Widget? icon;

  PackImageListItemData({
    this.title,
    this.subtitle,
    this.colorPrimary,
    this.cover,
    this.coverSize,
    this.icon,
    this.backgroundImage,
  });
}
