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
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/folders/folder_list_item_widget.dart';
import 'package:Medito/widgets/folders/loading_list_widget.dart';
import 'package:Medito/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FolderNavWidget extends StatefulWidget {
  FolderNavWidget({Key? key, this.id = ''}) : super(key: key);

  static const routeName = '/folder';
  final String id;

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
  }

  @override
  void didChangeDependencies() {
    if (_bloc.content == null) {
      _bloc.fetchData(id: widget.id);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        return _refresh(context, skipCache: true);
      },
      child: SafeArea(
        top: false,
        child: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return _getScreenContent();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context, {bool skipCache = false}) {
    return _bloc.fetchData(id: widget.id, skipCache: skipCache);
  }

  Widget _getScreenContent() => SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          HeaderWidget(
            primaryColorController: _bloc.primaryColorController,
            titleController: _bloc.titleController,
            coverController: _bloc.coverController,
            backgroundImageController: _bloc.backgroundImageController,
            descriptionController: _bloc.descriptionController,
          ),
          _getListStream(),
        ],
      ));

  StreamBuilder<ApiResponse<List<Item>>> _getListStream() =>
      StreamBuilder<ApiResponse<List<Item>>>(
          initialData: ApiResponse.loading(),
          stream: _bloc.itemsListController.stream,
          builder: (context, itemsSnapshot) {
            switch (itemsSnapshot.data?.status) {
              case null:
                break;
              case Status.LOADING:
                return Center(
                    child: CircularProgressIndicator(
                        backgroundColor: Colors.black,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            MeditoColors.walterWhite)));
              case Status.COMPLETED:
                return ListView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: itemsSnapshot.data?.body != null
                        ? itemsSnapshot.data?.body?.length
                        : 0,
                    shrinkWrap: true,
                    padding: EdgeInsets.only(top: 8),
                    itemBuilder: (BuildContext context, int i) {
                      return itemsSnapshot.data?.body != null
                          ? _getSlidingItem(
                              itemsSnapshot.data?.body?[i], context)
                          : Container();
                    });
              case Status.ERROR:
                return LoadingListWidget();
            }
            return Container();
          });

  Widget _getSlidingItem(Item? item, BuildContext context) {
    if (item == null) return Container();

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
      color: MeditoColors.moonlight,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Spacer(),
            getSwipeableActionIcon(item),
          ],
        ),
      ),
    );
  }

  Widget getSwipeableActionIcon(Item item) {
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

  void itemTap(Item item) {
    checkConnectivity().then((value) {

      if (value) {
          var location = GoRouter.of(context).location;
        if (item.type == 'folder') {
          if (location.contains('folder2')) {
            context.go(getPathFromString(Folder3Path, [location.split('/')[2], widget.id, item.id]));
          } else {
            context.go(getPathFromString(Folder2Path, [widget.id, item.id]));
          }
        } else {
          context.go(location + getPathFromString(item.type, [item.id]));
        }
      } else {
        createSnackBar(CHECK_CONNECTION, context);
      }
    });
  }
}
