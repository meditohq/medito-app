import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/empty_widget.dart';
import 'package:Medito/widgets/packs/pack_list_item.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class DownloadsListWidget extends StatefulWidget {
  @override
  _DownloadsListWidgetState createState() => _DownloadsListWidgetState();
}

class _DownloadsListWidgetState extends State<DownloadsListWidget>
    with SingleTickerProviderStateMixin {
  final key = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
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
                padding: EdgeInsets.symmetric(vertical: 8),
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
      onTap: () {
        _openPlayer(item, context);
      },
      child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: _getDismissibleBackgroundWidget(),
          onDismissed: (direction) {
            if (mounted) {
              DownloadsBloc.removeSessionFromDownloads(item).then((value) {
                return setState(() {});
              });
            }

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

  PackListItemWidget _getListItemWidget(MediaItem item) {
    var backgroundSoundString = '';
    if ((item.extras['bgMusicTitle'] as String)?.isNotEmptyAndNotNull() ??
        false) {
      backgroundSoundString = ' — ${item.extras['bgMusicTitle']}';
    }
    return PackListItemWidget(PackImageListItemData(
        title: item.title,
        subtitle:
            '${item.artist} — ${_getDuration(item.extras['length'])}$backgroundSoundString',
        cover: item.artUri,
        colorPrimary: parseColor(item.extras['primaryColor']),
        coverSize: 56));
  }

  String _getDuration(String length) => formatSessionLength(length);

  void _openPlayer(MediaItem item, BuildContext context) {
    start(item).then((value) {
      NavigationFactory.navigate(context, Screen.player,
          id: null, normalPop: true);
      return null;
    });
  }
}
