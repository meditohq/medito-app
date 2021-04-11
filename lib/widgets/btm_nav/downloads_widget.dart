import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/folder/folder_reponse.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/widgets/folders/folder_list_item_widget.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';

class DownloadsListWidget extends StatefulWidget {
  @override
  _DownloadsListWidgetState createState() => _DownloadsListWidgetState();
}

class _DownloadsListWidgetState extends State<DownloadsListWidget>
    with SingleTickerProviderStateMixin {
  final _bloc = DownloadsBloc();

  final key = GlobalKey<AnimatedListState>();

  ValueNotifier<List<MediaItem>> downloadedSession = DownloadsBloc.downloadedSessions;

  @override
  void initState() {
    super.initState();
    DownloadsBloc.fetchDownloads().then((value){
      if (value.isNotEmpty) {
        showSwipeToDeleteTip();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getDownloadList(),
    );
  }

  Widget _getDownloadList() {
    return ValueListenableBuilder(
        valueListenable: DownloadsBloc.downloadedSessions,
        builder: (context, sessionList, widget) {
          if (sessionList.isNotEmpty) {
            return ListView.builder(
                itemCount: sessionList.length,
                itemBuilder: (context, i) {
                  var item = sessionList[i];
                  return _getSlidingItem(item, context);
                });
          } else {
            return _getEmptyWidget();
          }
        });
  }

  Widget _getEmptyWidget() => Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 300,
            height: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.tag_faces,
                  color: MeditoColors.walterWhite,
                ),
                Container(
                  height: 32,
                ),
                Text(
                  'From now on, your downloads will appear here',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _getSlidingItem(MediaItem item, BuildContext context) {
    return InkWell(
      onTap: () {
        _openPlayer(item, context);
      },
      child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: _getDismissibleBackgroundWidget(),
          onDismissed: (direction) {
            setState(() {
              if (mounted) {
                DownloadsBloc.removeSessionFromDownloads(item);
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('"${item.title}" removed'),
            ));
          },
          child: _getListItemWidget(item)),
    );
  }

  Widget _getDismissibleBackgroundWidget() => Container(
        color: MeditoColors.moonlight,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(),
              Icon(
                Icons.delete,
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
      );

  ListItemWidget _getListItemWidget(MediaItem item) {
    return ListItemWidget(
      title: item.title,
      subtitle: '${item.artist} ▴ ${_getDuration(item.extras['length'])}',
      id: item.id,
      fileType: FileType.session,
    );
  }

  String _getDuration(String length) => formatSessionLength(length);

  void _openPlayer(MediaItem item, BuildContext context) {
    start(item).then((value) {
      NavigationFactory.navigate(context, Screen.player,
          id: null, normalPop: true);
      return null;
    });
  }

  void showSwipeToDeleteTip() async {
    await _bloc.seenTip().then((seen) {
        if (!seen) {
          unawaited(_bloc.setSeenTip());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    color: MeditoColors.walterWhite,
                  ),
                  Container(
                    width: 16,
                    height: 10,
                  ),
                  Text('Swipe away a session to delete it')
                ],
              ),
            ),
          );
        }
        ;
      });
   }
}
