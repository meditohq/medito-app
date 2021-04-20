/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/folder/folder_bloc.dart';
import 'package:Medito/network/folder/folder_response.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/widgets/folders/folder_banner_widget.dart';
import 'package:Medito/widgets/folders/folder_list_item_widget.dart';
import 'package:Medito/widgets/folders/loading_list_widget.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FolderStateless extends StatelessWidget {
  FolderStateless({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FolderNavWidget();
  }
}

class FolderNavWidget extends StatefulWidget {
  FolderNavWidget({Key key}) : super(key: key);

  static const routeName = '/folder';

  @override
  _FolderNavWidgetState createState() => _FolderNavWidgetState();
}

class _FolderNavWidgetState extends State<FolderNavWidget> {
  final FolderItemsBloc _bloc = FolderItemsBloc();

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.FOLDER_PAGE);
  }

  @override
  void didChangeDependencies() {
    if (_bloc.content == null) {
      final FolderArguments args = ModalRoute.of(context).settings.arguments;
      _bloc.fetchData(id: args.sessionId);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          return RefreshIndicator(
              onRefresh: () {
                final FolderArguments args =
                    ModalRoute.of(context).settings.arguments;
                return _bloc.fetchData(id: args.sessionId, skipCache: true);
              },
              child: _getScreenContent());
        },
      ),
    );
  }

  Widget _getScreenContent() => SingleChildScrollView(
          child: Column(
        children: [
          FolderBannerWidget(bloc: _bloc),
          _getListStream(),
        ],
      ));

  StreamBuilder<ApiResponse<List<Item>>> _getListStream() =>
      StreamBuilder<ApiResponse<List<Item>>>(
          stream: _bloc.itemsListController.stream,
          builder: (context, itemsSnapshot) {
            if (!itemsSnapshot.hasData ||
                itemsSnapshot.connectionState == ConnectionState.waiting) {
              return LoadingListWidget();
            }

            if (itemsSnapshot.hasData) {
              return ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: itemsSnapshot.data.body != null
                      ? itemsSnapshot.data.body.length
                      : 0,
                  shrinkWrap: true,
                  padding: EdgeInsets.only(top: 8),
                  itemBuilder: (BuildContext context, int i) {
                    return itemsSnapshot.data.body != null
                        ? _getSlidingItem(itemsSnapshot.data.body[i], context)
                        : Container();
                  });
            }

            return Container();
          });

  Widget _getSlidingItem(Item item, BuildContext context) {
    var childWidget;

// Only the audio sessions should have swipable action to toggle the dimissible status
// Other types like text file and folder should not have this option
    if (item.fileType != FileType.session) {
      childWidget = _getItemListWidget(item);
    } else {
      childWidget = Dismissible(
          resizeDuration: null,
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: _getDismissibleBackgroundWidget(item),
          onDismissed: (direction) {
            setState(() {
              toggleListenedStatus(item.id, item.oldId);
            });
          },
          child: _getItemListWidget(item));
    }

    return InkWell(
      onTap: () => itemTap(item),
      child: childWidget,
    );
  }

  Widget _getDismissibleBackgroundWidget(Item item) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Spacer(),
            getSwipableActionIcon(item),
          ],
        ),
      ),
    );
  }

  Widget getSwipableActionIcon(Item item) {
    if (checkListened(item.id, oldId: item.oldId)) {
      return Icon(
        Icons.play_circle_fill,
        color: MeditoColors.walterWhite,
      );
    } else {
      return Icon(
        Icons.check,
        color: MeditoColors.walterWhite,
      );
    }
  }

  ListItemWidget _getItemListWidget(Item item) {
    return ListItemWidget(
      title: item.title,
      subtitle: item.subtitle,
      id: item.id,
      oldId: item.oldId,
      fileType: item.fileType,
    );
  }

  void itemTap(Item i) {
    Tracking.trackEvent(Tracking.TAP, Tracking.FOLDER_TAPPED, i.id);
    NavigationFactory.navigate(
        context, NavigationFactory.getScreenFromItemType(i.fileType),
        id: i.id);
  }

  void startService(media, primaryColor) {
    start(media).then((value) {
      NavigationFactory.navigate(context, Screen.player, id: null);
      return null;
    });
  }
}

class FolderArguments {
  final String sessionId;

  FolderArguments(this.sessionId);
}
