import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/folder/folder_reponse.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
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
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _getDownloadList(),
        ],
      ),
    );
  }

  Widget _getDownloadList() {
    if (_list.isNotEmpty) {
      return Expanded(
        child: ListView.builder(
            itemCount: _list.length,
            itemBuilder: (context, i) {
              var item = _list[i];
              return _slidingItem(item, context);
            }),
      );
    } else {
      return Text('No downloads!');
    }
  }

  Widget _slidingItem(MediaItem item, BuildContext context) {
    return Expanded(
      flex: 1,
      child: GestureDetector(
        onTap: () {
          _openPlayer(item, context);
        },
        child: _getListItemWidget(item),
      ),
    );
  }

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

  void _getItems() async {
    await _bloc.fetchDownloads().then((value) => _updateList(value));
  }

  void _updateList(List<MediaItem> value) {
    _list = value;
    setState(() {});
  }
}
