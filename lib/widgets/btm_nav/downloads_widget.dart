import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/empty_widget.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:Medito/widgets/packs/pack_list_item.dart';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../audioplayer/audio_inherited_widget.dart';
import '../../main.dart';

class DownloadsListWidget extends StatefulWidget {
  @override
  _DownloadsListWidgetState createState() => _DownloadsListWidgetState();
}

class _DownloadsListWidgetState extends State<DownloadsListWidget>
    with SingleTickerProviderStateMixin {
  final key = GlobalKey<AnimatedListState>();
  var scaffoldKey = GlobalKey<ScaffoldState>();

  List<MediaItem> _downloadList = [];
  MeditoAudioHandler _audioHandler;

  @override
  void initState() {
    super.initState();
    _refreshDownloadList();
  }

  @override
  Widget build(BuildContext context) {
    _audioHandler = AudioHandlerInheritedWidget.of(context).audioHandler;

    return Scaffold(
      appBar: const MeditoAppBarWidget(
        title: DOWNLOADS,
        transparent: true,
        hasCloseButton: true,
      ),
      key: scaffoldKey,
      body: _downloadList.isEmpty ? _getEmptyWidget() : _getDownloadList(),
    );
  }

  Widget _getDownloadList() {
    // In order for the Dismissible action still to work on the list items,
    // the default ReorderableListView is used (instead of the .builder one)
    return ReorderableListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          var reorderedItem = _downloadList.removeAt(oldIndex);
          _downloadList.insert(newIndex, reorderedItem);
          // To ensure, that the new list order is saved
          DownloadsBloc.saveDownloads(_downloadList);
        });
      },
      children:
          _downloadList.map((item) => _getSlidingItem(item, context)).toList(),
    );
  }

  Widget _getEmptyWidget() => EmptyStateWidget(
        message: EMPTY_DOWNLOADS_MESSAGE,
        image: SvgPicture.asset(
          'assets/images/downloads.svg',
          height: 168,
          width: 178,
        ),
      );

  Widget _getSlidingItem(MediaItem item, BuildContext context) {
    return InkWell(
      // This (additional) key is required in order for the ReorderableListView to distinguish between the different list items
      key: ValueKey(item.id),
      onTap: () {
        _openPlayer(item, context);
      },
      child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: _getDismissibleBackgroundWidget(),
          onDismissed: (direction) {
            if (mounted) {
              _downloadList.removeWhere((element) => element == item);
              DownloadsBloc.removeSessionFromDownloads(context, item);
              setState(() {});
            }

            createSnackBar(
              '"${item.title}" removed',
              context,
              color: MeditoColors.moonlight,
            );
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

  PackListItemWidget _getListItemWidget(MediaItem item) {
    return PackListItemWidget(PackImageListItemData(
        title: item.title,
        subtitle: '${item.artist} — ${_getDuration(item.extras[LENGTH])}',
        cover: item.artUri.toString(),
        colorPrimary: parseColor(item.extras[PRIMARY_COLOUR]),
        coverSize: 56));
  }

  String _getDuration(String length) => formatSessionLength(length);

  void _openPlayer(MediaItem item, BuildContext context) {
    _audioHandler.playMediaItem(item);
    NavigationFactory.navigate(context, Screen.player,
        id: null, normalPop: true);
  }

  void showSwipeToDeleteTip() {
    createSnackBar(SWIPE_TO_DELETE, context, color: MeditoColors.darkMoon);
  }

  void _refreshDownloadList() {
    DownloadsBloc.fetchDownloads().then((value) {
      _downloadList = value;
      setState(() {});
    });
  }
}
