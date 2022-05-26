import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/shortcuts_bloc.dart';
import 'package:Medito/network/home/shortcuts_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SmallShortcutsRowWidget extends StatefulWidget {
  @override
  SmallShortcutsRowWidgetState createState() => SmallShortcutsRowWidgetState();

  SmallShortcutsRowWidget({Key key, this.onTap}) : super(key: key);

  final void Function(dynamic, dynamic) onTap;
}

class SmallShortcutsRowWidgetState extends State<SmallShortcutsRowWidget> {
  final _bloc = ShortcutsBloc();
  bool isLandscape = false;
  @override
  void initState() {
    super.initState();
    _bloc.fetchShortcuts();
  }

  void refresh() {
    _bloc.fetchShortcuts(skipCache: true);
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      if (MediaQuery.of(context).size.width > 600) {
        isLandscape = true;
      } else {
        isLandscape = false;
      }
      return SizeChangedLayoutNotifier(
          child: StreamBuilder<ApiResponse<ShortcutsResponse>>(
              stream: _bloc.shortcutList.stream,
              initialData: ApiResponse.loading(),
              builder: (context, snapshot) {
                switch (snapshot.data.status) {
                  case Status.LOADING:
                    return _getLoadingWidget();
                    break;
                  case Status.COMPLETED:
                    return GridView.count(
                      crossAxisCount: isLandscape ? 4 : 2,
                      padding: const EdgeInsets.only(
                          left: 12.0, right: 12.0, top: 8.0),
                      scrollDirection: Axis.vertical,
                      childAspectRatio: 2.6,
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: List.generate(
                          snapshot.data.body?.data?.length ?? 0, (index) {
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          clipBehavior: Clip.antiAlias,
                          color: MeditoColors.deepNight,
                          child: SmallShortcutWidget(
                              snapshot.data.body.data[index], widget.onTap),
                        );
                      }),
                    );
                    break;
                  case Status.ERROR:
                    return Icon(Icons.error);
                    break;
                }
                return Container();
              }));
    });
  }

  Widget _getLoadingWidget() => GridView.count(
        crossAxisCount: isLandscape ? 4 : 2,
        padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 8.0),
        scrollDirection: Axis.vertical,
        childAspectRatio: 2.6,
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: List.generate(4, (index) {
          if (index == 0) {
            // Show a link to the downloads page when the app is loading
            return _getLocalDownloadsWidget();
          } else {
            return Card(
              clipBehavior: Clip.antiAlias,
              color: MeditoColors.deepNight,
              child: Container(),
            );
          }
        }),
  );

  Card _getLocalDownloadsWidget() {
    return Card(
        clipBehavior: Clip.antiAlias,
        color: MeditoColors.almostBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SmallShortcutWidget(
            ShortcutData(
                title: 'Downloads',
                type: 'app',
                id: 'downloads',
                cover: null,
                backgroundImage: null,
                colorPrimary: '#ff282828'),
            widget.onTap)
    );
  }
}

class SmallShortcutWidget extends StatelessWidget {
  final ShortcutData data;
  final Function onTap;

  SmallShortcutWidget(this.data, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: MeditoColors.softGrey,
      onTap: () => onTap(data.type, data.id),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getListItemLeadingImageWidget(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 4),
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
      overflow: TextOverflow.visible,
      wrapWords: false,
      maxLines: 2,
      style: Theme.of(context).textTheme.subtitle2);

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
