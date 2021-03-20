import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/folder/folder_items.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/folders/folder_list_item_widget.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class DownloadsListWidget extends StatefulWidget {
  @override
  _DownloadsListWidgetState createState() => _DownloadsListWidgetState();
}

class _DownloadsListWidgetState extends State<DownloadsListWidget>
    with SingleTickerProviderStateMixin {
  final _bloc = DownloadsBloc();

  final key = GlobalKey<AnimatedListState>();
  var _deleteActionActivated = false;

  List<MediaItem> _list = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          MeditoAppBarWidget(title: 'Downloads', actions: _getActions()),
          getDownloadList(),
        ],
      ),
    );
  }

  Widget getDownloadList() {
    return _list.isNotEmpty
        ? Expanded(
            child: AnimatedList(
                key: key,
                initialItemCount: _list.length,
                itemBuilder: (context, i, animation) {
                  var item = _list[i];

                  var duration = _getDuration(
                      Duration(milliseconds: item.extras['duration']));

                  return _slidingItem(animation, item, context, duration, i);
                }))
        : Container();
  }

  SlideTransition _slidingItem(Animation<double> animation, MediaItem item,
      BuildContext context, String duration, int i) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset(0, 0),
      ).animate(CurvedAnimation(parent: animation, curve: Curves.ease)),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                _openPlayer(item, context);
              },
              child: _getListItemWidget(item, duration),
            ),
          ),
          _deleteActionActivated
              ? Expanded(
                  flex: 0,
                  child: IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: MeditoColors.walterWhite,
                      ),
                      onPressed: () {
                        key.currentState.removeItem(
                            i,
                            (context, animation) => _slidingItem(
                                animation, item, context, duration, i));
                      }),
                )
              : Container()
        ],
      ),
    );
  }

  ListItemWidget _getListItemWidget(MediaItem item, String duration) {
    return ListItemWidget(
      title: item.title,
      subtitle: duration,
      id: item.id,
      fileType: FileType.session,
    );
  }

  void _openPlayer(MediaItem item, BuildContext context) {
    start(item).then((value) {
      NavigationFactory.navigate(context, Screen.player,
          id: null, normalPop: true);
      return null;
    });
  }

  String _getDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    var twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    var twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  List<Widget> _getActions() {
    if (!_deleteActionActivated) {
      return [
        GestureDetector(
          onTap: () {
            _deleteActionActivated = true;
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.delete),
          ),
        )
      ];
    } else {
      return [
        GestureDetector(
          onTap: () {
            _deleteActionActivated = false;
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.check_circle),
          ),
        )
      ];
    }
  }

  void _getItems() async {
    await _bloc.fetchDownloads().then((value) => _updateList(value));
  }

  void _updateList(List<MediaItem> value) {
    _list = value;
    setState(() {});
  }
}
