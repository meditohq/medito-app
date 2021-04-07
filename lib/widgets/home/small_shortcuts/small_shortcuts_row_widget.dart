import 'package:Medito/network/packs/packs_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SmallShortcutsRowWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      scrollDirection: Axis.vertical,
      childAspectRatio: 2.6,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: List.generate(4, (index) {
        return Card(
          clipBehavior: Clip.antiAlias,
          color: MeditoColors.deepNight,
          child: SmallShortcutWidget(PacksData()),
        );
      }),
    );
  }
}

class SmallShortcutWidget extends StatelessWidget {
  final PacksData data;

  SmallShortcutWidget(this.data);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _getListItemLeadingImageWidget(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(11.0),
            child: _getTitle(context),
          ),
        ),
      ],
    );
  }

  Widget _getTitle(BuildContext context) =>
      AutoSizeText('data.title',
          maxFontSize: 14,
          stepGranularity: 2,
          overflow: TextOverflow.fade,
          wrapWords: false,
          maxLines: 2,
          style: Theme.of(context)
              .textTheme
              .subtitle1
              .copyWith(color: MeditoColors.walterWhite, fontSize: 14));

  Widget _getListItemLeadingImageWidget() => Container(
        color: Colors.blue,
        // color: parseColor(data.colorPrimary),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: AspectRatio(
            aspectRatio: 1,
            child: getNetworkImageWidget(
                'https://i.picsum.photos/id/33/536/354.jpg?hmac=dr3g8fDBO7YqDieYQlNLa3FzuRJnuthiLi-JKQrwtQk'),
          ),
        ),
      );
}
