import 'package:Medito/network/home/shortcuts_bloc.dart';
import 'package:Medito/network/home/shortcuts_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../network/api_response.dart';
import '../../../utils/navigation.dart';
import '../../../utils/utils.dart';

class SmallShortcutsRowWidget extends StatelessWidget {
  final _bloc = ShortcutsBloc();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ApiResponse<ShortcutsResponse>>(
        stream: _bloc.shortcutList.stream,
        initialData: ApiResponse.loading(),
        builder: (context, snapshot) {
          switch (snapshot.data.status) {
            case Status.LOADING:
              return _getLoadingWidget();
              break;
            case Status.COMPLETED:
              return GridView.count(
                crossAxisCount: 2,
                padding:
                    const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                scrollDirection: Axis.vertical,
                childAspectRatio: 2.6,
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children:
                    List.generate(snapshot.data.body.data.length, (index) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: MeditoColors.deepNight,
                    child: SmallShortcutWidget(snapshot.data.body.data[index]),
                  );
                }),
              );
              break;
            case Status.ERROR:
              return Icon(Icons.error);
              break;
          }
          return Container();
        });
  }

  Center _getLoadingWidget() => Center(child: CircularProgressIndicator());
}

class SmallShortcutWidget extends StatelessWidget {
  final ShortcutData data;

  SmallShortcutWidget(this.data);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => NavigationFactory.navigateToScreenFromString(
          data.type, data.id, context),
      child: Row(
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
      ),
    );
  }

  Widget _getTitle(BuildContext context) => AutoSizeText(data.title,
      maxFontSize: 14,
      stepGranularity: 2,
      overflow: TextOverflow.fade,
      wrapWords: false,
      maxLines: 2,
      style: Theme.of(context)
          .textTheme
          .subtitle2);

  Widget _getListItemLeadingImageWidget() => Container(
        color: parseColor(data.colorPrimary),
        child: Stack(
          children: [
            _getBackgroundImage(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: getNetworkImageWidget(data.coverUrl),
              ),
            ),
          ],
        ),
      );

  Widget _getBackgroundImage() => data.backgroundImage.isNotEmptyAndNotNull()
      ? getNetworkImageWidget(data.bgImageUrl)
      : Container();
}
